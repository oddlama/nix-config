{
  lib,
  pkgs,
  config,
  nodeSecrets,
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

  boot = {
    kernelParams = ["log_buf_len=10M"];
    tmpOnTmpfs = true;
  };
  environment.etc."nixos/configuration.nix".source = dummyConfig;

  # Disable sudo which is entierly unnecessary.
  security.sudo.enable = false;

  time.timeZone = lib.mkDefault "Europe/Berlin";
  i18n.defaultLocale = "C.UTF-8";

  console =
    {
      keyMap = "de-latin1-nodeadkeys";
    }
    // lib.optionalAttrs config.hardware.video.hidpi.enable {
      font = "ter-v28n";
      packages = with pkgs; [terminus_font];
    };

  hardware = {
    enableRedistributableFirmware = true;
    enableAllFirmware = true;
  };

  networking = {
    # FIXME: would like to use mkForce false for useDHCP, but nixpkgs#215908 blocks that.
    useDHCP = true;
    useNetworkd = true;
    wireguard.enable = true;
    dhcpcd.enable = false;
    nftables.enable = true;
    firewall.enable = true;
  };

  # Rename known network interfaces
  services.udev.packages = let
    interfaceNamesUdevRules = pkgs.writeTextFile {
      name = "interface-names-udev-rules";
      text = lib.concatStringsSep "\n" (lib.mapAttrsToList (
          interface: attrs: ''SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="${attrs.mac}", NAME:="${interface}"''
        )
        nodeSecrets.networking.interfaces);
      destination = "/etc/udev/rules.d/01-interface-names.rules";
    };
  in [interfaceNamesUdevRules];

  nix.nixPath = [
    "nixos-config=${dummyConfig}"
    "nixpkgs=/run/current-system/nixpkgs"
    "nixpkgs-overlays=/run/current-system/overlays"
  ];

  system = {
    extraSystemBuilderCmds = ''
      ln -sv ${pkgs.path} $out/nixpkgs
      ln -sv ${../../../nix/overlays} $out/overlays
    '';

    stateVersion = "22.11";
  };

  systemd = {
    enableUnifiedCgroupHierarchy = true;
    network.wait-online.anyInterface = true;
  };

  users.mutableUsers = false;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    verbose = true;
  };

  programs = {
    # Required even when using home-manager's zsh module since the /etc/profile load order
    # is partly controlled by this. See nix-community/home-manager#3681.
    zsh.enable = true;
    git = {
      enable = true;
      config = {
        init.defaultBranch = "main";
        pull.rebase = true;
      };
    };
  };

  services = {
    fwupd.enable = true;
    smartd.enable = true;
    thermald.enable = builtins.elem config.nixpkgs.system ["x86_64-linux"];
  };
}
