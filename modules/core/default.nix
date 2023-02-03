{
  lib,
  pkgs,
  config,
  ...
}: let
  dummyConfig = pkgs.writeText "configuration.nix" ''
    assert builtins.trace "This is a dummy config, use colmena!" false;
    { }
  '';
in {
  imports = [
    ./inputrc.nix
    ./issue.nix
    ./nix.nix
    ./resolved.nix
    ./ssh.nix
    ./tmux.nix
    ./xdg.nix
  ];

  boot.kernelParams = ["log_buf_len=10M"];
  environment.etc."nixos/configuration.nix".source = dummyConfig;

  # Disable sudo which is entierly unnecessary.
  security.sudo.enable = false;

  rekey.hostPubkey = ../../secrets/pubkeys + "/${config.networking.hostName}.pub";
  rekey.masterIdentities = [../../secrets/yk1-nix-rage.pub];
  rekey.extraEncryptionPubkeys = [../../secrets/backup.pub];

  rekey.secrets.yolo.file = ./yolo.age;
  environment.etc."YOLO".source = config.rekey.secrets.yolo.path;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    verbose = true;
  };

  time.timeZone = lib.mkDefault "Europe/Berlin";
  i18n.defaultLocale = "C.UTF-8";

  networking = {
    useDHCP = lib.mkForce false;
    useNetworkd = true;
    wireguard.enable = true;
    dhcpcd.enable = false;
    nftables.enable = true;
    firewall.enable = true;
  };

  nix.nixPath = [
    "nixos-config=${dummyConfig}"
    "nixpkgs=/run/current-system/nixpkgs"
    "nixpkgs-overlays=/run/current-system/overlays"
  ];

  programs = {
    git = {
      enable = true;
      config = {
        init.defaultBranch = "main";
        pull.rebase = true;
      };
    };
  };

  system = {
    extraSystemBuilderCmds = ''
      ln -sv ${pkgs.path} $out/nixpkgs
      ln -sv ${../../nix/overlays} $out/overlays
    '';

    stateVersion = "22.11";
  };

  systemd = {
    enableUnifiedCgroupHierarchy = true;
    network.wait-online.anyInterface = true;
  };

  users.mutableUsers = false;
}
