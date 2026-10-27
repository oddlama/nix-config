{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  inherit (lib)
    mkDefault
    mkEnableOption
    mkIf
    mkOption
    mkPackageOption
    ;

  cfg = config.services.antirion;
  dataDir = "/var/lib/antirion";
  configFile = "/run/antirion/config.json";
  format = pkgs.formats.json { };

  # Unlike other secret fields, config-declared virtual keys MUST be references,
  # not literal values. Keep the same _secret interface, but point these at
  # credentials rather than substituting their plaintext into the JSON.
  keySecrets = lib.filterAttrs (_: key: lib.isAttrs (key.secret or null) && key.secret ? _secret) (
    cfg.settings.keys or { }
  );
  keyCredentialName = name: "key-${builtins.hashString "sha256" name}";
  keyFiles = lib.mapAttrs (_: key: key.secret._secret) keySecrets // cfg.retiredKeyFiles;
  renderedSettings =
    cfg.settings
    // lib.optionalAttrs (cfg.settings ? keys) {
      keys = lib.mapAttrs (
        name: key: if builtins.hasAttr name keySecrets then key // { secret = null; } else key
      ) cfg.settings.keys;
    };
  keySecretFilter = lib.concatStringsSep " | " (
    lib.mapAttrsToList (
      name: _:
      ''.keys[${builtins.toJSON name}].secret = ("$" + "{file:" + $credentials + "/${keyCredentialName name}}")''
    ) keySecrets
  );

  secretsReplacement = utils.genJqSecretsReplacement {
    loadCredential = true;
  } renderedSettings configFile;

  secretPaths =
    map (secret: secret._secret) (
      lib.attrValues (utils.recursiveGetAttrsetWithJqPrefix cfg.settings "_secret")
    )
    ++ lib.attrValues cfg.retiredKeyFiles;
  # Track encrypted inputs, never plaintext contents. This also covers friends'
  # keys and upstream credentials, not just the two secrets declared below.
  usedAgeSecrets = lib.filter (secret: lib.elem secret.path secretPaths) (
    lib.attrValues config.age.secrets
  );
in
{
  options.services.antirion = {
    enable = mkEnableOption "the Antirion AI gateway";
    package = mkPackageOption pkgs "antirion" { };

    retiredKeyFiles = mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = lib.literalExpression ''
        { alice = config.age.secrets.antirion-alice.path; }
      '';
      description = ''
        Temporary credential files for keys declared through secret._secret and
        removed from settings.keys. Antirion 0.1.1 resolves the persisted snapshot
        before applying pruning, so its old
        key references must remain readable during that startup.

        Remove the key from settings.keys and add its name/file here in the same
        switch, retaining the agenix secret. After a successful startup/prune,
        remove this entry and the agenix secret in a second switch. This does not
        provision or enable a key; it only supplies the old credential while
        startup reconciles the stored configuration. Do not use this to retire
        a key while admin.config.prune is false or retained resources reference it.
      '';
    };

    settings = mkOption {
      type = lib.types.submodule { freeformType = format.type; };
      default = { };
      example = lib.literalExpression ''
        {
          server.listen = "127.0.0.1:8080";
          admin.listen = "127.0.0.1:8081";
          auth.admin.public_origin = "https://ai-admin.example.org";
          admin.ui.data_plane_url = "https://ai.example.org";
          keys.friend.secret._secret = config.age.secrets.antirion-friend.path;
        }
      '';
      description = ''
        Antirion's configuration, rendered as JSON and validated before startup.
        See the schema in `share/antirion/config.schema.json` of the package.

        Provision providers, deployments, models, routes, users, keys, limits,
        budgets and prices here. Resources are applied as source `nixos`, with
        pruning and UI/API edit locking enabled by default. Pruning only affects
        resources owned by that source; separately UI-created resources remain.

        Use `{ _secret = config.age.secrets.<name>.path; }` for secret values,
        including inside lists. systemd loads these as credentials, so agenix
        files can remain root-owned with mode 0400 despite DynamicUser.
        For keys.<name>.secret, the module emits a file reference to a stable
        credential name because Antirion rejects literal virtual-key secrets.
        Those files must contain raw keys (quote = false is not supported).
        Never put plaintext secrets or `builtins.readFile` of a secret here.

        Configuration changes restart the service. Referenced agenix secrets
        also trigger a restart when their encrypted files change; other secret
        files require a manual restart after rotation. There is no live reload.

        This module manages the embedded SQLite store and spool in
        /var/lib/antirion. See ./antirion.md for provisioning and backup notes.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion =
          cfg.settings.store.backend == "embedded"
          && cfg.settings.store.embedded.path == dataDir
          && cfg.settings.store.spool.path == "${dataDir}/spool";
        message = "services.antirion manages an embedded SQLite store and spool under ${dataDir}; do not override these store paths or select PostgreSQL.";
      }
      {
        assertion = cfg.settings.admin.config.file == null && !cfg.settings.admin.config.watch;
        message = "services.antirion uses restart-on-change provisioning from settings, not admin.config.file/watch.";
      }
      {
        assertion = lib.all (key: key.secret.quote or true) (lib.attrValues keySecrets);
        message = "services.antirion.settings.keys.<name>.secret._secret must reference a raw key file; quote = false is not supported here.";
      }
      {
        assertion = lib.intersectAttrs (cfg.settings.keys or { }) cfg.retiredKeyFiles == { };
        message = "services.antirion.retiredKeyFiles must only contain keys removed from settings.keys.";
      }
      {
        assertion = cfg.retiredKeyFiles == { } || cfg.settings.admin.config.prune;
        message = "services.antirion.retiredKeyFiles requires admin.config.prune = true.";
      }
    ];

    # The repo's agenix-rekey configuration supplies generatedSecretsDir and the
    # host recipient. Generate/rekey these before the first deployment.
    age.secrets = {
      antirion-bootstrap-token.generator.script = "alnum";
      # Antirion requires base64 of exactly 32 bytes; agenix-rekey's base64
      # generator produces that. Keep this key when restoring the SQLite store.
      antirion-encryption-key.generator.script = "base64";
    };

    # Data-plane keys have a checksummed format; plain alnum passwords are not
    # accepted. Use generator.script = "antirion-api-key" for friends' keys.
    age.generators.antirion-api-key =
      { pkgs, ... }: "${lib.getExe pkgs.python3} ${./antirion-keygen.py}";

    services.antirion.settings = {
      version = mkDefault 1;
      server.listen = mkDefault "127.0.0.1:8080";
      admin = {
        listen = mkDefault "127.0.0.1:8081";
        config = {
          file = mkDefault null;
          watch = mkDefault false;
          source = mkDefault "nixos";
          prune = mkDefault true;
          lock_applied = mkDefault true;
        };
      };
      store = {
        backend = mkDefault "embedded";
        embedded.path = mkDefault dataDir;
        spool.path = mkDefault "${dataDir}/spool";
        logs.backend = mkDefault "primary";
      };
      auth = {
        mode = mkDefault "required";
        admin.bootstrap_token = mkDefault {
          _secret = config.age.secrets.antirion-bootstrap-token.path;
        };
      };
      security.secrets.encryption_keys = mkDefault [
        { _secret = config.age.secrets.antirion-encryption-key.path; }
      ];
    };

    systemd.services.antirion = {
      description = "Antirion AI gateway";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      restartTriggers = map (secret: secret.file) usedAgeSecrets;

      preStart = ''
        ${secretsReplacement.script}
        ${lib.optionalString (keySecrets != { }) ''
          ${lib.getExe pkgs.jq} --arg credentials "$CREDENTIALS_DIRECTORY" \
            ${lib.escapeShellArg keySecretFilter} ${configFile} > ${configFile}.tmp
          mv ${configFile}.tmp ${configFile}
        ''}
        chmod 0600 ${configFile}
        ${lib.getExe cfg.package} validate -f ${configFile}
      '';

      serviceConfig = {
        Type = "exec";
        ExecStart = "${lib.getExe cfg.package} serve --config ${configFile}";
        Restart = "on-failure";
        RestartSec = 3;
        LoadCredential =
          secretsReplacement.credentials
          ++ lib.mapAttrsToList (name: file: "${keyCredentialName name}:${file}") keyFiles;

        DynamicUser = true;
        User = "antirion";
        StateDirectory = "antirion";
        StateDirectoryMode = "0700";
        RuntimeDirectory = "antirion";
        RuntimeDirectoryMode = "0700";
        WorkingDirectory = dataDir;
        UMask = "0077";

        CapabilityBoundingSet = "";
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProcSubset = "pid";
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [ "@system-service" ];
        # Do not enable MemoryDenyWriteExecute: Antirion embeds Wasmtime's JIT.
      };
    };
  };
}
