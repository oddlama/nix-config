{
  config,
  lib,
  pkgs,
  ...
}: let
  dummyConfig = pkgs.writeText "configuration.nix" ''
    assert builtins.trace "This is a dummy config, use deploy-rs!" false;
    { }
  '';
in {
  imports = [
    ./nix.nix
    ./resolved.nix
    ./tmux.nix
    ./xdg.nix
    ./ssh.nix
  ];

  boot.kernelParams = ["log_buf_len=10M"];

  environment = {
    etc."nixos/configuration.nix".source = dummyConfig;
    pathsToLink = [
      "/share/zsh"
    ];
    systemPackages = with pkgs; [
      neovim
    ];
  };

  # Disable unnecessary stuff from the nixos defaults.
  services.udisks2.enable = false;
  networking.dhcpcd.enable = false;
  networking.firewall.enable = false;
  security.sudo.enable = false;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    verbose = true;
  };

  time.timeZone = lib.mkDefault "Europe/Berlin";
  i18n.defaultLocale = "C.UTF-8";

  networking = {
    # When using systemd-networkd it's still possible to use this option,
    # but it's recommended to use it in conjunction with explicit per-interface
    # declarations with `networking.interfaces.<interface>.useDHCP`.
    useDHCP = lib.mkForce false;
    useNetworkd = true;
    wireguard.enable = true;
  };

  nix.nixPath = [
    "nixos-config=${dummyConfig}"
    "nixpkgs=/run/current-system/nixpkgs"
    "nixpkgs-overlays=/run/current-system/overlays"
  ];

  nixpkgs.config.allowUnfree = true;

  programs = {
    zsh = {
      enable = true;
      enableGlobalCompInit = false;
    };
  };

  system = {
    extraSystemBuilderCmds = ''
      ln -sv ${pkgs.path} $out/nixpkgs
      ln -sv ${../nix/overlays} $out/overlays
    '';

    stateVersion = "22.11";
  };

  systemd = {
    enableUnifiedCgroupHierarchy = true;
    network.wait-online.anyInterface = true;
  };

  users.mutableUsers = false;
}
