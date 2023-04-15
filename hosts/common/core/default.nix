{
  inputs,
  lib,
  pkgs,
  config,
  nodeName,
  ...
}: {
  imports = [
    ./inputrc.nix
    ./issue.nix
    ./net.nix
    ./nix.nix
    ./resolved.nix
    ./ssh.nix
    ./tmux.nix
    ./xdg.nix

    ../../../modules/wireguard.nix
  ];

  # Setup secret rekeying parameters
  rekey = {
    inherit
      (inputs.self.secrets)
      masterIdentities
      extraEncryptionPubkeys
      ;

    forceRekeyOnSystem = "x86_64-linux";
    hostPubkey = let
      pubkeyPath = ../.. + "/${nodeName}/secrets/host.pub";
    in
      lib.mkIf (lib.pathExists pubkeyPath || lib.trace "Missing pubkey for ${nodeName}: ${toString pubkeyPath} not found, using dummy replacement key for now." false)
      pubkeyPath;
  };

  boot = {
    kernelParams = ["log_buf_len=10M"];
    tmpOnTmpfs = true;
  };

  # Disable sudo which is entierly unnecessary.
  security.sudo.enable = false;

  time.timeZone = lib.mkDefault "Europe/Berlin";
  i18n.defaultLocale = "C.UTF-8";
  console.keyMap = "de-latin1-nodeadkeys";

  hardware = {
    enableRedistributableFirmware = true;
    enableAllFirmware = true;
  };

  systemd.enableUnifiedCgroupHierarchy = true;
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
