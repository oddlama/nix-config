{
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
    systemPackages = with pkgs; [
      neovim
    ];
    variables.EDITOR = "nvim";
  };

  # Disable unnecessary stuff from the nixos defaults.
  services.udisks2.enable = false;
  security.sudo.enable = false;

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
    firewall.enable = false;
  };

  nix.nixPath = [
    "nixos-config=${dummyConfig}"
    "nixpkgs=/run/current-system/nixpkgs"
    "nixpkgs-overlays=/run/current-system/overlays"
  ];

  nixpkgs.config.allowUnfree = true;

  programs = {
    git = {
      enable = true;
      config = {
        init.defaultBranch = "main";
        pull.rebase = true;
      };
    };
    neovim = {
      enable = true;
      viAlias = true;
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

  users.users.root = {
    initialHashedPassword = "$6$EBo/CaxB.dQoq2W8$lo2b5vKgJlLPdGGhEqa08q3Irf1Zd1PcFBCwJOrG8lqjwbABkn1DEhrMh1P3ezwnww2HusUBuZGDSMa4nvSQg1";
    openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5Uq+CDy5Pmt3If5M6d8K/Q7HArU6sZ7sgoj3T521Wm"];
  };
  users.mutableUsers = false;
}
