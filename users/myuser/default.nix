{
  config,
  pkgs,
  ...
}: let
  myuser = config.repo.secrets.global.myuser.name;
in {
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

  age.secrets.mailpw-206fd3b8 = {
    rekeyFile = ./secrets/mailpw-206fd3b8.age;
    group = myuser;
    mode = "640";
  };

  home-manager.users.${myuser} = {
    imports = [
      ../modules
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
  };
}
