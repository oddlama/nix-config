{
  config,
  lib,
  ...
}: let
  smbUsers = config.repo.secrets.local.samba.users;
  smbGroups = config.repo.secrets.local.samba.groups;
in {
  age.secrets."samba-passdb.tdb" = {
    rekeyFile = config.node.secretsDir + "/samba-passdb.tdb.age";
    mode = "600";
  };

  fileSystems."/storage".neededForBoot = true;
  environment.persistence."/storage" = {
    hideMounts = true;
    directories =
      lib.flip lib.mapAttrsToList smbUsers (name: _: {
        directory = "/shares/users/${name}";
        user = name;
        group = name;
        mode = "0750";
      })
      ++ lib.flip lib.mapAttrsToList smbGroups (name: _: {
        directory = "/shares/groups/${name}";
        user = name;
        group = name;
        mode = "0750";
      });
  };

  services.samba = {
    enable = true;
    openFirewall = true;

    # Disable Samba's nmbd, because we don't want to reply to NetBIOS over IP
    # requests, since all of our clients hardcode the server shares.
    enableNmbd = false;
    # Disable Samba's winbindd, which provides a number of services to the Name
    # Service Switch capability found in most modern C libraries, to arbitrary
    # applications via PAM and ntlm_auth and to Samba itself.
    enableWinbindd = false;
    extraConfig = lib.concatLines [
      # Show the server host name in the printer comment box in print manager
      # and next to the IPC connection in net view.
      "server string = my-nas"
      # Set the NetBIOS name by which the Samba server is known.
      "netbios name = my-nas"
      # Disable netbios support. We don't need to support browsing since all
      # clients hardcode the host and share names.
      "disable netbios = yes"
      # Deny access to all hosts by default.
      "hosts deny = 0.0.0.0/0"
      # Allow access to local network and TODO: wireguard
      "hosts allow = 192.168.1.0/24"

      # Set sane logging options
      "log level = 0 auth:2 passdb:2"
      "log file = /dev/null"
      "max log size = 0"
      "logging = systemd"

      # TODO: allow based on wireguard ip without username and password
      # Users always have to login with an account and are never mapped
      # to a guest account.
      "passdb backend = tdbsam:${config.age.secrets."samba-passdb.tdb".path}"
      "server role = standalone"
      "guest account = nobody"
      "map to guest = never"

      # Clients should only connect using the latest SMB3 protocol (e.g., on
      # clients running Windows 8 and later).
      "server min protocol = SMB3_11"
      # Require native SMB transport encryption by default.
      "server smb encrypt = required"

      # Disable printer sharing. By default Samba shares printers configured
      # using CUPS.
      "load printers = no"
      "printing = bsd"
      "printcap name = /dev/null"
      "disable spoolss = yes"
      "show add printer wizard = no"

      # Load in modules (order is critical!) and enable AAPL extensions.
      "vfs objects = catia fruit streams_xattr"
      # Enable Apple's SMB2+ extension.
      "fruit:aapl = yes"
      # Clean up unused or empty files created by the OS or Samba.
      "fruit:wipe_intentionally_left_blank_rfork = yes"
      "fruit:delete_empty_adfiles = yes"
    ];
    shares = let
      mkShare = path: cfg:
        {
          inherit path;
          public = "no";
          writable = "yes";
          "create mask" = "0740";
          "directory mask" = "0750";
          # "force create mode" = "0660";
          # "force directory mode" = "0770";
          "acl allow execute always" = "yes";
        }
        // cfg;

      mkGroupShare = group:
        mkShare "/shares/groups/${group}" {
          "valid users" = "@${group}";
          "force user" = "family";
          "force group" = group;
        };

      mkUserShare = user:
        mkShare "/shares/users/${user}" {
          "valid users" = user;
        };
    in
      {}
      // lib.mapAttrs (name: _: mkUserShare name) smbUsers
      // lib.mapAttrs (name: _: mkGroupShare name) smbGroups;
  };

  users.users = let
    mkUser = name: id: groups: {
      isNormalUser = true;
      uid = id;
      group = name;
      extraGroups = groups;
      createHome = false;
      home = "/var/empty";
      useDefaultShell = false;
      autoSubUidGidRange = false;
    };
  in
    {}
    // lib.mapAttrs (name: cfg: mkUser name cfg.id cfg.groups) smbUsers
    // lib.mapAttrs (name: cfg: mkUser name cfg.id []) smbGroups;

  users.groups = lib.mapAttrs (_: cfg: {gid = cfg.id;}) (smbUsers // smbGroups);
}