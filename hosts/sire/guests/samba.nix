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

  mkUserShares = user: {enableBunker ? false, ...}:
    [
      (mkShare user "/shares/users/${user}" {
        "valid users" = user;
      })
    ]
    ++ lib.optional enableBunker (
      mkShare "${user}-bunker" "/shares/users/${user}-bunker" {
        "valid users" = user;
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

  fileSystems."/storage".neededForBoot = true;
  fileSystems."/bunker".neededForBoot = true;
  environment.persistence = lib.mkMerge ([
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
    ));

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
    shares = lib.mkMerge (lib.flatten (
      lib.mapAttrsToList mkUserShares smbUsers
      ++ lib.mapAttrsToList mkGroupShares smbGroups
    ));
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
      }
    ];

  users.groups = lib.mapAttrs (_: cfg: {gid = cfg.id;}) (smbUsers // smbGroups);

  # Backups
  # ========================================================================

  age.secrets.restic-encryption-password.generator.script = "alnum";
  age.secrets.restic-ssh-privkey.generator.script = "ssh-ed25519";

  services.restic.backups.main = {
    hetznerStorageBox = let
      box = config.repo.secrets.global.hetzner.storageboxes.dusk;
    in {
      enable = true;
      inherit (box) mainUser;
      inherit (box.users.samba) subUid path;
      sshAgeSecret = "restic-ssh-privkey";
    };

    user = "root";
    timerConfig = {
      OnCalendar = "06:15";
      RandomizedDelaySec = "3h";
      Persistent = true;
    };
    initialize = true;
    passwordFile = config.age.secrets.restic-encryption-password.path;
    paths = ["/bunker"];
    pruneOpts = [
      "--keep-daily 14"
      "--keep-weekly 7"
      "--keep-monthly 12"
      "--keep-yearly 75"
    ];
  };
}
