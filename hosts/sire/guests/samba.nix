{
  config,
  lib,
  ...
}: let
  smbUsers = config.repo.secrets.local.samba.users;
  smbGroups = config.repo.secrets.local.samba.groups;

  mkPersistent = persistRoot: directory: owner: {
    ${persistRoot}.directories = [
      {
        inherit directory;
        user = owner;
        group = owner;
        mode = "0750";
      }
    ];
  };

  mkShare = id: path: cfg: {
    ${id} =
      {
        inherit path;
        public = "no";
        writable = "yes";
        "create mask" = "0740";
        "directory mask" = "0750";
        "acl allow execute always" = "yes";
      }
      // cfg;
  };

  mkGroupShares = group: {enableBunker ? false, ...}:
    [
      (mkShare group "/shares/groups/${group}" {
        "valid users" = "@${group}";
        "force user" = group;
        "force group" = group;
      })
    ]
    ++ lib.optional enableBunker (
      mkShare "${group}-bunker" "/shares/groups/${group}-bunker" {
        "valid users" = "@${group}";
        "force user" = group;
        "force group" = group;
      }
    );

  mkUserShares = user: {
    enableBunker ? false,
    enablePaperless ? false,
    ...
  }:
    [
      (mkShare user "/shares/users/${user}" {
        "valid users" = user;
      })
    ]
    ++ lib.optional enableBunker (
      mkShare "${user}-bunker" "/shares/users/${user}-bunker" {
        "valid users" = user;
      }
    )
    ++ lib.optional enablePaperless (
      mkShare "${user}-paperless" "/shares/users/${user}-paperless" {
        "valid users" = user;
        "force user" = "paperless";
        "force group" = "paperless";
      }
    );
in {
  age.secrets."samba-passdb.tdb" = {
    rekeyFile = config.node.secretsDir + "/samba-passdb.tdb.age";
    mode = "600";
  };

  services.openssh = {
    # You really have to hate them. Thanks Brother ADS-4300N.
    settings = {
      Macs = ["hmac-sha2-512"];
      HostkeyAlgorithms = "+ssh-rsa";
      PubkeyAcceptedAlgorithms = "+ssh-rsa";
    };
    # We need an RSA key for network attached printers and scanners
    # that fucking can't be bothered to support sensible stuff
    hostKeys = [
      {
        bits = 4096;
        path = "/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
      }
    ];

    # Allow SFTP for scanner in /shares/groups/scanner
    extraConfig = ''
      Match User scanner
        ForceCommand internal-sftp
        AllowTcpForwarding no
        PermitTunnel no
    '';
  };

  environment.persistence = lib.mkMerge (
    [
      {
        "/persist".files = [
          "/etc/ssh/ssh_host_rsa_key"
          "/etc/ssh/ssh_host_rsa_key.pub"
        ];
      }
    ]
    ++ lib.flatten (
      lib.flip lib.mapAttrsToList smbUsers (
        name: {enableBunker ? false, ...}:
          [(mkPersistent "/storage" "/shares/users/${name}" name)]
          ++ lib.optional enableBunker (
            mkPersistent "/bunker" "/shares/users/${name}-bunker" name
          )
      )
      ++ lib.flip lib.mapAttrsToList smbGroups (
        name: {enableBunker ? false, ...}:
          [(mkPersistent "/storage" "/shares/groups/${name}" name)]
          ++ lib.optional enableBunker (
            mkPersistent "/bunker" "/shares/groups/${name}-bunker" name
          )
      )
    )
  );

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
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
      "server string = SambaOelig"
      # Set the NetBIOS name by which the Samba server is known.
      "netbios name = SambaOelig"
      # Disable netbios support. We don't need to support browsing since all
      # clients hardcode the host and share names.
      "disable netbios = yes"
      # Deny access to all hosts by default.
      "hosts deny = 0.0.0.0/0"
      # Allow access to local network and TODO: wireguard
      "hosts allow = 192.168.1.0/24"
      # Don't advertise inaccessible shares to users
      "access based share enum = yes"

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

      # Never map anything to the excutable bit.
      "map archive = no"
      "map system = no"
      "map hidden = no"

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
    shares = lib.mkMerge (lib.flatten (
      lib.mapAttrsToList mkUserShares smbUsers
      ++ lib.mapAttrsToList mkGroupShares smbGroups
    ));
  };

  systemd.tmpfiles.settings = lib.mkMerge (
    # Make sure the main paperless structure exists
    [
      {
        "10-smb-paperless" = {
          "/paperless/consume".d = {
            user = "paperless";
            group = "paperless";
            mode = "0750";
          };
          "/paperless/media".d = {
            user = "paperless";
            group = "paperless";
            mode = "0750";
          };
          "/paperless/media/documents".d = {
            user = "paperless";
            group = "paperless";
            mode = "0750";
          };
          "/paperless/media/documents/archive".d = {
            user = "paperless";
            group = "paperless";
            mode = "0750";
          };
          "/paperless/media/documents/originals".d = {
            user = "paperless";
            group = "paperless";
            mode = "0750";
          };
        };
      }
    ]
    # For each paperless share, make sure the necessary sub-folders for that user are created
    # at boot so we can bind-mount them into the shares.
    ++ lib.flatten (lib.flip lib.mapAttrsToList smbUsers (
      user: userCfg:
        lib.optional (userCfg.enablePaperless or false) {
          "10-smb-paperless" = {
            "/shares/users/${user}-paperless".d = {
              user = "paperless";
              group = "paperless";
              mode = "0550";
            };
            "/paperless/consume/${user}".d = {
              user = "paperless";
              group = "paperless";
              mode = "0750";
            };
            "/paperless/media/documents/archive/${user}".d = {
              user = "paperless";
              group = "paperless";
              mode = "0750";
            };
            # A .keep file prevents paperless from removing this folder if no documents are present
            "/paperless/media/documents/archive/${user}/.keep".f = {
              user = "paperless";
              group = "paperless";
              mode = "0640";
            };
            "/paperless/media/documents/originals/${user}".d = {
              user = "paperless";
              group = "paperless";
              mode = "0750";
            };
            # A .keep file prevents paperless from removing this folder if no documents are present
            "/paperless/media/documents/originals/${user}/.keep".f = {
              user = "paperless";
              group = "paperless";
              mode = "0640";
            };
          };
        }
    ))
  );

  # For each paperless share, bind-mount create the necessary folders using tmpfiles.
  fileSystems = lib.mkMerge (
    [
      {
        "/storage".neededForBoot = true;
        "/bunker".neededForBoot = true;
      }
    ]
    ++ lib.flip lib.mapAttrsToList smbUsers (
      user: userCfg:
        lib.optionalAttrs (userCfg.enablePaperless or false) {
          "/shares/users/${user}-paperless/consume" = {
            fsType = "none";
            options = ["bind"];
            device = "/paperless/consume/${user}";
          };
          "/shares/users/${user}-paperless/documents" = {
            fsType = "none";
            options = ["bind" "ro"];
            device = "/paperless/media/documents/archive/${user}";
          };
          "/shares/users/${user}-paperless/originals" = {
            fsType = "none";
            options = ["bind" "ro"];
            device = "/paperless/media/documents/originals/${user}";
          };
        }
    )
  );

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
    lib.mkMerge [
      (
        {}
        // lib.mapAttrs (name: cfg: mkUser name cfg.id cfg.groups) smbUsers
        // lib.mapAttrs (name: cfg: mkUser name cfg.id []) smbGroups
      )
      {
        scanner.openssh.authorizedKeys.keys = [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDJcWkqM2gXM9MJoKggCMpXLBJvgPP0fuoIO3UNy4h4uFzyDqMKAADjaJHCqyIQPq/s5vATVmuu4GQyajkc7Y3fBg/2rvAACzFx/2ufK2M4dkdDcYOX6kyNZL7XiJRmLfUR2cqda3P3bQxapkdfIOWfPQQJUAnYlVvUaIShoBxYw5HXRTr2jR5UAklfIRWZOmx07WKC6dZG5MIm1Luun5KgvqQmzQ9ErL5tz/Oi5pPdK30kdkS5WdeWD6KwL78Ff4KfC0DVTO0zb/C7WyKk4ZLu+UKCLHXDTzE4lhBAu6mSUfJ5nQhmdLdKg6Gvh1St/vRcsDJOZqEFBVn35/oK974l root@ADS_4300N_BRN000EC691D285"
        ];

        paperless = {
          group = "paperless";
          uid = config.ids.uids.paperless;
          home = "/var/empty";
        };
      }
    ];

  users.groups =
    {
      paperless.gid = config.ids.gids.paperless;
    }
    // lib.mapAttrs (_: cfg: {gid = cfg.id;}) (smbUsers // smbGroups);

  backups.storageBoxes.dusk = {
    subuser = "samba";
    paths = ["/bunker"];
  };
}
