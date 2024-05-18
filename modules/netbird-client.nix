{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    attrValues
    concatLists
    concatStringsSep
    escapeShellArgs
    filterAttrs
    getExe
    literalExpression
    maintainers
    makeBinPath
    mapAttrs'
    mapAttrsToList
    mkDefault
    mkIf
    mkMerge
    mkOption
    mkOptionDefault
    mkPackageOption
    mkRemovedOptionModule
    nameValuePair
    optional
    optionalString
    toShellVars
    versionAtLeast
    versionOlder
    ;

  inherit
    (lib.types)
    attrsOf
    bool
    enum
    package
    port
    str
    submodule
    ;

  inherit (config.boot) kernelPackages;
  inherit (config.boot.kernelPackages) kernel;

  cfg = config.services.netbird;

  toClientList = fn: map fn (attrValues cfg.clients);
  toClientAttrs = fn: mapAttrs' (_: fn) cfg.clients;

  hardenedClients = filterAttrs (_: client: client.hardened) cfg.clients;
  toHardenedClientList = fn: map fn (attrValues hardenedClients);
  toHardenedClientAttrs = fn: mapAttrs' (_: fn) hardenedClients;
in {
  meta.maintainers = with maintainers; [
    misuzu
    thubrecht
    nazarewk
  ];

  imports = [
    (mkRemovedOptionModule ["services" "netbird" "tunnels"]
      "The option `services.netbird.tunnels` has been renamed to `services.netbird.clients`")
  ];

  options.services.netbird = {
    enable = mkOption {
      type = bool;
      default = false;
      description = ''
        Enables backwards compatible Netbird client service.

        This is strictly equivalent to:

        ```nix
        services.netbird.clients.wt0 = {
          port = 51820;
          name = "netbird";
          interface = "wt0";
          hardened = false;
        };
        ```
      '';
    };
    package = mkPackageOption pkgs "netbird" {};

    ui.enable = mkOption {
      type = bool;
      default = config.services.displayManager.sessionPackages != [];
      defaultText = literalExpression ''config.services.displayManager.sessionPackages != [ ]'';
      description = ''
        Controls presence `netbird-ui` wrappers, defaults to presence of graphical sessions.
      '';
    };
    ui.package = mkPackageOption pkgs "netbird-ui" {};

    clients = mkOption {
      type = attrsOf (
        submodule (
          {
            name,
            config,
            ...
          }: {
            options = {
              port = mkOption {
                type = port;
                example = literalExpression "51820";
                description = ''
                  Port the Netbird client listens on.
                '';
              };

              name = mkOption {
                type = str;
                default = "netbird-${name}";
                description = ''
                  Primary name for use in:
                  - systemd service name,
                  - hardened user name and group,
                  - [systemd `*Directory=`](https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html#RuntimeDirectory=) names,
                  - desktop application identification,
                '';
              };

              interface = mkOption {
                type = str;
                default = "netbird-${name}";
                description = ''
                  Name of the network interface managed by this client.
                '';
              };

              environment = mkOption {
                type = attrsOf str;
                defaultText = literalExpression ''
                  {
                    NB_CONFIG = "/var/lib/''${config.name}/config.json";
                    NB_DAEMON_ADDR = "unix:///var/run/''${config.name}/sock";
                    NB_INTERFACE_NAME = config.interface;
                    NB_LOG_FILE = mkOptionDefault "console";
                    NB_LOG_LEVEL = config.logLevel;
                    NB_SERVICE = config.name;
                    NB_WIREGUARD_PORT = toString config.port;
                  }
                '';
                description = ''
                  Environment for the netbird service, used to pass configuration options.
                '';
              };

              autoStart = mkOption {
                type = bool;
                default = true;
                description = ''
                  Start the service with the system.

                  As of 2024-02-13 it is not possible to start a Netbird client daemon without immediately
                  connecting to the network, but it is [planned for a near future](https://github.com/netbirdio/netbird/projects/2#card-91718018).
                '';
              };

              openFirewall = mkOption {
                type = bool;
                default = true;
                description = ''
                  Opens up firewall `port` for communication between Netbird peers directly over LAN or public IP,
                  without using (internet-hosted) TURN servers as intermediaries.
                '';
              };

              hardened = mkOption {
                type = bool;
                default = true;
                description = ''
                  Hardened service:
                  - runs as a dedicated user with minimal set of permissions (see caveats),
                  - restricts daemon configuration socket access to dedicated user group
                    (you can grant access to it with `users.users."<user>".extraGroups = [ "netbird-${name}" ]`),

                  Even though the local system resources access is restricted:
                  - `CAP_NET_RAW`, `CAP_NET_ADMIN` and `CAP_BPF` still give unlimited network manipulation possibilites,
                  - older kernels don't have `CAP_BPF` and use `CAP_SYS_ADMIN` instead,

                  Known security features that are not (yet) integrated into the module:
                  - 2024-02-14: `rosenpass` is an experimental feature configurable solely
                    through `--enable-rosenpass` flag on the `netbird up` command,
                    see [the docs](https://docs.netbird.io/how-to/enable-post-quantum-cryptography)
                '';
              };

              logLevel = mkOption {
                type = enum [
                  # logrus loglevels
                  "panic"
                  "fatal"
                  "error"
                  "warn"
                  "warning"
                  "info"
                  "debug"
                  "trace"
                ];
                default = "info";
                description = "Log level of the Netbird daemon.";
              };

              wrapper = mkOption {
                type = package;
                internal = true;
                default = let
                  makeWrapperArgs = concatLists (
                    mapAttrsToList
                    (key: value: ["--set-default" key value])
                    config.environment
                  );
                in
                  pkgs.stdenv.mkDerivation {
                    name = "${cfg.package.name}-wrapper-${name}";
                    meta.mainProgram = "netbird-${name}";
                    nativeBuildInputs = with pkgs; [makeWrapper];
                    phases = ["installPhase"];
                    installPhase = concatStringsSep "\n" [
                      ''
                        mkdir -p "$out/bin"
                        makeWrapper ${lib.getExe cfg.package} "$out/bin/netbird-${name}" \
                          ${escapeShellArgs makeWrapperArgs}
                      ''
                      (optionalString cfg.ui.enable ''
                        # netbird-ui doesn't support envvars
                        makeWrapper ${lib.getExe cfg.ui.package}-ui "$out/bin/netbird-ui-${name}" \
                          --add-flags '--daemon-addr=${config.environment.NB_DAEMON_ADDR}'

                        mkdir -p "$out/share/applications"
                        substitute ${cfg.ui.package}/share/applications/netbird.desktop \
                            "$out/share/applications/netbird-${name}.desktop" \
                          --replace-fail 'Name=Netbird' "Name=Netbird @ ${config.name}" \
                          --replace-fail '${lib.getExe cfg.ui.package}-ui' "$out/bin/netbird-ui-${name}"
                      '')
                    ];
                  };
              };

              # see https://github.com/netbirdio/netbird/blob/88747e3e0191abc64f1e8c7ecc65e5e50a1527fd/client/internal/config.go#L49-L82
              config = mkOption {
                inherit (pkgs.formats.json {}) type;
                defaultText = literalExpression ''
                  {
                    DisableAutoConnect = !config.autoStart;
                    WgIface = config.interface;
                    WgPort = config.port;
                  }
                '';
                description = ''
                  Additional configuration that exists before the first start and
                  later overrides the existing values in `config.json`.

                  It is mostly helpful to manage configuration ignored/not yet implemented
                  outside of `netbird up` invocation.

                  WARNING: this is not an upstream feature, it could break in the future
                  (by having lower priority) after upstream implements an equivalent.

                  It is implemented as a `preStart` script which overrides `config.json`
                  with content of `/etc/netbird-${name}/config.d/*.json` files.
                  This option manages specifically `50-nixos.json` file.

                  Consult [the source code](https://github.com/netbirdio/netbird/blob/88747e3e0191abc64f1e8c7ecc65e5e50a1527fd/client/internal/config.go#L49-L82)
                  or inspect existing file for a complete list of available configurations.
                '';
              };
            };

            config.environment = {
              NB_CONFIG = "/var/lib/${config.name}/config.json";
              NB_DAEMON_ADDR = "unix:///var/run/${config.name}/sock";
              NB_INTERFACE_NAME = config.interface;
              NB_LOG_FILE = mkOptionDefault "console";
              NB_LOG_LEVEL = config.logLevel;
              NB_SERVICE = config.name;
              NB_WIREGUARD_PORT = toString config.port;
            };

            config.config = {
              DisableAutoConnect = !config.autoStart;
              WgIface = config.interface;
              WgPort = config.port;
            };
          }
        )
      );
      default = {};
      description = ''
        Attribute set of Netbird client daemons, by default each one will:

        1. be manageable using dedicated tooling:
          - `netbird-<name>` script,
          - `Netbird - netbird-<name>` graphical interface when appropriate (see `ui.enable`),
        2. run as a `netbird-<name>.service`,
        3. listen for incoming remote connections on the port `51830` (`openFirewall` by default),
        4. manage the `netbird-<name>` wireguard interface,
        5. use the `/var/lib/netbird-<name>/config.json` configuration file,
        6. override `/var/lib/netbird-<name>/config.json` with values from `/etc/netbird-<name>/config.d/*.json`,
        7. (`hardened`) be locally manageable by `netbird-<name>` system group,

        With following caveats:

        - multiple daemons will interfere with each other's DNS resolution of `netbird.cloud`, but
          should remain fully operational otherwise.
          Setting up custom (non-conflicting) DNS zone is currently possible only when self-hosting.
      '';
      example = lib.literalExpression ''
        {
          services.netbird.clients.wt0.port = 51820;
          services.netbird.clients.personal.port = 51821;
          services.netbird.clients.work1.port = 51822;
        }
      '';
    };
  };

  config = mkMerge [
    (mkIf cfg.enable (
      let
        name = "wt0";
        client = cfg.clients."${name}";
      in {
        services.netbird.clients."${name}" = {
          port = mkDefault 51820;
          name = mkDefault "netbird";
          interface = mkDefault "wt0";
          hardened = mkDefault false;
        };

        environment.systemPackages = [
          (lib.hiPrio (pkgs.runCommand "${name}-as-default" {} ''
            mkdir -p "$out/bin"
            for binary in netbird ${optionalString cfg.ui.enable "netbird-ui"} ; do
              ln -s "${client.wrapper}/bin/$binary-${name}" "$out/bin/$binary"
            done
          ''))
        ];
      }
    ))
    {
      boot.extraModulePackages =
        optional
        (cfg.clients != {} && (versionOlder kernel.version "5.6"))
        kernelPackages.wireguard;

      environment.systemPackages =
        toClientList (client: client.wrapper)
        # omitted due to https://github.com/netbirdio/netbird/issues/1562
        #++ optional (cfg.clients != { }) cfg.package
        # omitted due to https://github.com/netbirdio/netbird/issues/1581
        #++ optional (cfg.clients != { } && cfg.ui.enable) cfg.ui.package
        ;

      networking.dhcpcd.denyInterfaces = toClientList (client: client.interface);
      networking.networkmanager.unmanaged = toClientList (client: "interface-name:${client.interface}");

      networking.firewall.allowedUDPPorts = concatLists (toClientList (client: optional client.openFirewall client.port));

      systemd.network.networks = mkIf config.networking.useNetworkd (toClientAttrs (
        client:
          nameValuePair "50-netbird-${client.interface}" {
            matchConfig = {
              Name = client.interface;
            };
            linkConfig = {
              Unmanaged = true;
              ActivationPolicy = "manual";
            };
          }
      ));

      environment.etc = toClientAttrs (client:
        nameValuePair "${client.name}/config.d/50-nixos.json" {
          text = builtins.toJSON client.config;
          mode = "0444";
        });

      systemd.services = toClientAttrs (client:
        nameValuePair client.name {
          description = "A WireGuard-based mesh network that connects your devices into a single private network";

          documentation = ["https://netbird.io/docs/"];

          after = ["network.target"];
          wantedBy = ["multi-user.target"];

          path = optional (!config.services.resolved.enable) pkgs.openresolv;

          serviceConfig = {
            ExecStart = "${getExe client.wrapper} service run";
            Restart = "always";

            RuntimeDirectory = client.name;
            RuntimeDirectoryMode = mkDefault "0755";
            ConfigurationDirectory = client.name;
            StateDirectory = client.name;
            StateDirectoryMode = "0700";

            WorkingDirectory = "/var/lib/${client.name}";
          };

          unitConfig = {
            StartLimitInterval = 5;
            StartLimitBurst = 10;
          };

          stopIfChanged = false;
        });
    }
    # Hardening section
    (mkIf (hardenedClients != {}) {
      users.groups = toHardenedClientAttrs (client: nameValuePair client.name {});
      users.users = toHardenedClientAttrs (client:
        nameValuePair client.name {
          isSystemUser = true;
          home = "/var/lib/${client.name}";
          group = client.name;
        });

      systemd.services = toHardenedClientAttrs (client:
        nameValuePair client.name (mkIf client.hardened {
          serviceConfig = {
            RuntimeDirectoryMode = "0750";

            User = client.name;
            Group = client.name;

            # settings implied by DynamicUser=true, without actully using it,
            # see https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html#DynamicUser=
            RemoveIPC = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = "yes";

            AmbientCapabilities =
              [
                # see https://man7.org/linux/man-pages/man7/capabilities.7.html
                # see https://docs.netbird.io/how-to/installation#running-net-bird-in-docker
                #
                # seems to work fine without CAP_SYS_ADMIN and CAP_SYS_RESOURCE
                # CAP_NET_BIND_SERVICE could be added to allow binding on low ports, but is not required,
                #  see https://github.com/netbirdio/netbird/pull/1513

                # failed creating tunnel interface wt-priv: [operation not permitted
                "CAP_NET_ADMIN"
                # failed to pull up wgInterface [wt-priv]: failed to create ipv4 raw socket: socket: operation not permitted
                "CAP_NET_RAW"
              ]
              # required for eBPF filter, used to be subset of CAP_SYS_ADMIN
              ++ optional (versionAtLeast kernel.version "5.8") "CAP_BPF"
              ++ optional (versionOlder kernel.version "5.8") "CAP_SYS_ADMIN";
          };
        }));

      # see https://github.com/systemd/systemd/blob/17f3e91e8107b2b29fe25755651b230bbc81a514/src/resolve/org.freedesktop.resolve1.policy#L43-L43
      security.polkit.extraConfig = mkIf config.services.resolved.enable ''
        // systemd-resolved access for Netbird clients
        polkit.addRule(function(action, subject) {
          var actions = [
            "org.freedesktop.resolve1.set-dns-servers",
            "org.freedesktop.resolve1.set-domains",
          ];
          var users = ${builtins.toJSON (toHardenedClientList (client: client.name))};

          if (actions.indexOf(action.id) >= 0 && users.indexOf(subject.user) >= 0 ) {
            return polkit.Result.YES;
          }
        });
      '';
    })
    # migration & temporary fixups section
    {
      systemd.services = toClientAttrs (client:
        nameValuePair client.name {
          preStart = ''
            set -eEuo pipefail
            ${optionalString (client.logLevel == "trace" || client.logLevel == "debug") "set -x"}

            PATH="${makeBinPath (with pkgs; [coreutils jq diffutils])}:$PATH"
            export ${toShellVars client.environment}

            # merge /etc/${client.name}/config.d' into "$NB_CONFIG"
            {
              test -e "$NB_CONFIG" || echo -n '{}' > "$NB_CONFIG"

              # merge config.d with "$NB_CONFIG" into "$NB_CONFIG.new"
              jq -sS 'reduce .[] as $i ({}; . * $i)' \
                "$NB_CONFIG" \
                /etc/${client.name}/config.d/*.json \
                > "$NB_CONFIG.new"

              echo "Comparing $NB_CONFIG with $NB_CONFIG.new ..."
              if ! diff <(jq -S <"$NB_CONFIG") "$NB_CONFIG.new" ; then
                echo "Updating $NB_CONFIG ..."
                mv "$NB_CONFIG.new" "$NB_CONFIG"
              else
                echo "Files are the same, not doing anything."
                rm "$NB_CONFIG.new"
              fi
            }
          '';
        });
    }
  ];
}
