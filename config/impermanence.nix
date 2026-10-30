{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    any
    attrNames
    concatMapStrings
    filter
    hasPrefix
    mkIf
    optionals
    ;

  # Persistence roots that persist something below /var/lib/private
  rootsWithPrivateDirs = filter (
    root:
    any (
      dir: hasPrefix "/var/lib/private/" dir.directory
    ) config.environment.persistence.${root}.directories
  ) (attrNames config.environment.persistence);
in
{
  # Impermanence copies owner and mode from the persistent side onto every parent of a
  # persisted directory on each activation, and creates missing ones with 0755. systemd
  # refuses to start DynamicUser services when /var/lib/private isn't 0700, so make sure
  # its persistent counterpart is 0700 before impermanence propagates it.
  system.activationScripts = mkIf (rootsWithPrivateDirs != [ ]) {
    persistentVarLibPrivateMode.text = concatMapStrings (root: ''
      mkdir -p ${root}/var/lib
      mkdir -p -m 0700 ${root}/var/lib/private
      chmod 0700 ${root}/var/lib/private
    '') rootsWithPrivateDirs;
    createPersistentStorageDirs.deps = [ "persistentVarLibPrivateMode" ];
  };

  # Give agenix access to the hostkey independent of impermanence activation
  age.identityPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];

  # State that should be kept across reboots, but is otherwise
  # NOT important information in any way that needs to be backed up.
  fileSystems."/state".neededForBoot = true;
  environment.persistence."/state" = {
    hideMounts = true;
    directories = [
      "/var/lib/systemd"
      "/var/log"
      "/var/spool"
      #{ directory = "/tmp"; mode = "1777"; }
      #{ directory = "/var/tmp"; mode = "1777"; }
    ]
    ++ optionals config.networking.wireless.iwd.enable [
      {
        directory = "/var/lib/iwd";
        mode = "0700";
      }
    ];
  };

  # State that should be kept forever, and backed up accordingly.
  fileSystems."/persist".neededForBoot = true;
  environment.persistence."/persist" = {
    hideMounts = true;
    files = [
      # For ephemeral nixos-containers we cannot link the /etc/machine-id file,
      # because it will be generated based on a stable container uuid.
      (lib.mkIf (!config.boot.isContainer) "/etc/machine-id")
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
    ];
    directories = [
      "/var/lib/nixos"
    ]
    ++ optionals config.security.acme.acceptTerms [
      {
        directory = "/var/lib/acme";
        user = "acme";
        group = "acme";
        mode = "0755";
      }
    ]
    ++ optionals config.services.printing.enable [
      {
        directory = "/var/lib/cups";
        mode = "0755";
      }
    ]
    ++ optionals config.services.postgresql.enable [
      {
        directory = "/var/lib/postgresql";
        user = "postgres";
        group = "postgres";
        mode = "0700";
      }
    ];
  };
}
