{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    attrNames
    flip
    isAttrs
    mapAttrs
    mkMerge
    mkOption
    optionals
    types
    ;
in {
  # Give agenix access to the hostkey independent of impermanence activation
  age.identityPaths = ["/persist/etc/ssh/ssh_host_ed25519_key"];

  # Expose a home manager module for each user that allows extending
  # environment.persistence.${sourceDir}.users.${userName} simply by
  # specifying home.persistence.${sourceDir} in home manager.
  home-manager.sharedModules = [
    {
      options.home.persistence = mkOption {
        description = "Additional persistence config for the given source path";
        default = {};
        type = types.attrsOf (types.submodule {
          options = {
            files = mkOption {
              description = "Additional files to persist via NixOS impermanence.";
              type = types.listOf (types.either types.attrs types.str);
              default = [];
            };

            directories = mkOption {
              description = "Additional directories to persist via NixOS impermanence.";
              type = types.listOf (types.either types.attrs types.str);
              default = [];
            };
          };
        });
      };
    }
  ];

  # For each user that has a home-manager config, merge the locally defined
  # persistence options that we defined above.
  imports = let
    mkUserFiles = map (x:
      {parentDirectory.mode = "700";}
      // (
        if isAttrs x
        then x
        else {file = x;}
      ));
    mkUserDirs = map (x:
      {mode = "700";}
      // (
        if isAttrs x
        then x
        else {directory = x;}
      ));
  in [
    {
      environment.persistence = mkMerge (
        flip map
        (attrNames config.home-manager.users)
        (
          user: let
            hmUserCfg = config.home-manager.users.${user};
          in
            flip mapAttrs hmUserCfg.home.persistence
            (_: sourceCfg: {
              users.${user} = {
                files = mkUserFiles sourceCfg.files;
                directories = mkUserDirs sourceCfg.directories;
              };
            })
        )
      );
    }
  ];

  # State that should be kept across reboots, but is otherwise
  # NOT important information in any way that needs to be backed up.
  fileSystems."/state".neededForBoot = true;
  environment.persistence."/state" = {
    hideMounts = true;
    directories =
      [
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
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
    ];
    directories =
      [
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
          mode = "0700";
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
