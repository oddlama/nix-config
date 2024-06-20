{
  config,
  lib,
  pkgs,
  minimal,
  ...
}: let
  myuser = config.repo.secrets.global.myuser.name;
in
  lib.optionalAttrs (!minimal) {
    users.groups.${myuser}.gid = config.users.users.${myuser}.uid;
    users.users.${myuser} = {
      uid = 1000;
      inherit (config.repo.secrets.global.myuser) hashedPassword;
      createHome = true;
      group = myuser;
      extraGroups = ["wheel" "input" "video"];
      isNormalUser = true;
      autoSubUidGidRange = false;
      shell = pkgs.zsh;
    };

    repo.secretFiles.user-myuser = ./secrets/user.nix.age;

    age.secrets.my-gpg-pubkey-yubikey = {
      rekeyFile = ./secrets/yubikey.gpg.age;
      group = myuser;
      mode = "640";
    };

    age.secrets."my-gpg-yubikey-keygrip.tar" = {
      rekeyFile = ./secrets/gpg-keygrip.tar.age;
      group = myuser;
      mode = "640";
    };

    home-manager.users.${myuser} = {
      imports = [
        ../config
        ./dev
        ./graphical
        ./neovim

        ./git.nix
        ./gpg.nix
        ./ssh.nix
      ];

      # Remove dependence on username (which also comes from these secrets) to
      # avoid triggering infinite recursion.
      userSecretsName = "user-myuser";
      home = {
        inherit (config.users.users.${myuser}) uid;
        username = config.users.users.${myuser}.name;
      };

      # Autostart hyprland if on tty1 (once, don't restart after logout)
      programs.zsh.initExtra = lib.mkOrder 9999 ''
        if [[ -t 0 && "$(tty || true)" == /dev/tty1 && -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]]; then
          echo "Login shell detected. Starting hyprland..."
          dbus-run-session Hyprland
        fi
      '';
    };

    # Autologin
    services.getty.autologinUser = myuser;
  }
