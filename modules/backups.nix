{
  config,
  globals,
  lib,
  ...
}:
let
  inherit (lib)
    attrValues
    flip
    mkIf
    mkMerge
    mkOption
    types
    ;
in
{
  options.backups.storageBoxes = mkOption {
    description = "Backups to Hetzner Storage Boxes using restic";
    default = { };
    type = types.attrsOf (
      types.submodule (submod: {
        options = {
          name = mkOption {
            description = "The name of the storage box to backup to. The box must be defined in the globals. Defaults to the attribute name.";
            default = submod.config._module.args.name;
            type = types.str;
          };

          subuser = mkOption {
            description = "The name of the storage box subuser as defined in the globals, mapping this user to a subuser id.";
            type = types.str;
          };

          paths = mkOption {
            description = "The paths to backup.";
            type = types.listOf types.path;
          };
        };
      })
    );
  };

  config = mkIf (config.backups.storageBoxes != { }) {
    age.secrets.restic-encryption-password.generator.script = "alnum";
    age.secrets.restic-ssh-privkey.generator.script = "ssh-ed25519";

    services.restic.backups = mkMerge (
      flip map (attrValues config.backups.storageBoxes) (boxCfg: {
        "storage-box-${boxCfg.name}" = {
          hetznerStorageBox =
            let
              box = globals.hetzner.storageboxes.${boxCfg.name};
            in
            {
              enable = true;
              inherit (box) mainUser;
              inherit (box.users.${boxCfg.subuser}) subUid path;
              sshAgeSecret = "restic-ssh-privkey";
            };

          # A) We need to backup stuff from other users, so run as root.
          # B) We also need to be root because the ssh key will only
          #    be accessible to root so whatever service is running cannot
          #    just access our backup server.
          user = "root";

          inherit (boxCfg) paths;
          timerConfig = {
            OnCalendar = "06:15";
            RandomizedDelaySec = "3h";
            Persistent = true;
          };
          initialize = true;
          passwordFile = config.age.secrets.restic-encryption-password.path;
          # We cannot prune ourselves, since the remote repository will be append-only
          # pruneOpts = [
          #   "--keep-daily 14"
          #   "--keep-weekly 7"
          #   "--keep-monthly 12"
          #   "--keep-yearly 75"
          # ];
        };
      })
    );
  };
}
