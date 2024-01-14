{lib, ...}: let
  inherit
    (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
in {
  options.services.restic.backups = {
    type = types.attrsOf (types.submodule ({config}: {
      options.hetznerStorageBox = {
        enable = mkEnableOption "Automatically configure this backup to use the given hetzner storage box. Will use SFTP via SSH.";

        mainUser = mkOption {
          type = types.str;
          description = ''
            The main user. While not technically required for restic, we still use it to
            derive the subuser name and it is required for the automatic setup script
            that creates the users.
          '';
        };

        subUid = mkOption {
          type = types.int;
          description = "The id of the subuser that was allocated on the hetzner server for this backup.";
        };

        path = mkOption {
          type = types.str;
          description = ''
            The remote path to backup into. While not technically required for restic
            (since the subuser is chrooted on the remote), we'll still use it to set
            a sane repository and it is required for the automatic setup script that
            creates the users.
          '';
        };

        sshPrivateKeyFile = {
          type = types.path;
          description = "The path to the ssh private key to use for uploading backups. Don't use a path from the nix store!";
        };
      };

      config = let
        subUser = "${config.hetznerStorageBox.mainUser}-sub${toString config.hetznerStorageBox.subUid}";
        url = "${subUser}@${subUser}.your-storagebox.de";
      in
        mkIf config.hetznerStorageBox.enable {
          repository = "sftp://${url}:23${config.hetznerStorageBox.path}";
          extraOptions = [
            "sftp.command='ssh -s sftp -p 23 -i ${config.hetznerStorageBox.sshPrivateKeyFile} ${url}'"
          ];
        };
    }));
  };
}
