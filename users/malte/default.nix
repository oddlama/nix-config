{
  config,
  lib,
  globals,
  pkgs,
  minimal,
  ...
}:
lib.optionalAttrs (!minimal) {
  users.groups.malte.gid = config.users.users.malte.uid;
  users.users.malte = {
    uid = 1000;
    inherit (globals.malte) hashedPassword;
    createHome = true;
    group = "malte";
    extraGroups = [
      "wheel"
      "input"
      "video"
      "plugdev"
    ];
    isNormalUser = true;
    autoSubUidGidRange = false;
    shell = pkgs.zsh;
  };

  repo.secretFiles.user-malte = ./secrets/user.nix.age;

  age.secrets.my-gpg-pubkey-yubikey = {
    rekeyFile = ./secrets/yubikey.gpg.age;
    group = "malte";
    mode = "640";
  };

  age.secrets."my-gpg-yubikey-keygrip.tar" = {
    rekeyFile = ./secrets/gpg-keygrip.tar.age;
    group = "malte";
    mode = "640";
  };

  home-manager.users.malte = {
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
    userSecretsName = "user-malte";
    home = {
      username = config.users.users.malte.name;
    };

    # Autostart hyprland if on tty1 (once, don't restart after logout)
    programs.zsh.initContent = lib.mkOrder 9999 ''
      if [[ -t 0 && "$(tty || true)" == /dev/tty1 && -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]]; then
        echo "Login shell detected. Starting wayland..."
        niri
      fi
    '';
  };

  # Autologin
  services.getty.autologinUser = "malte";

  # Allow screen recorder to access the framebuffer as root
  programs.gpu-screen-recorder.enable = true;
}
