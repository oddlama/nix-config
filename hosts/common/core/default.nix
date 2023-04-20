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

  # IP address math library
  # https://gist.github.com/duairc/5c9bb3c922e5d501a1edb9e7b3b845ba
  # Plus some extensions by us
  lib = let
    libWithNet = (import "${inputs.lib-net}/net.nix" {inherit lib;}).lib;
  in
    lib.recursiveUpdate libWithNet {
      net.cidr = rec {
        hostCidr = n: x: "${libWithNet.net.cidr.host n x}/${libWithNet.net.cidr.length x}";
        ip = x: lib.head (lib.splitString "/" x);
        canonicalize = x: libWithNet.net.cidr.make (libWithNet.net.cidr.length x) (ip x);
      };
    };

  # Setup secret rekeying parameters
  rekey = {
    inherit
      (inputs.self.secrets)
      masterIdentities
      extraEncryptionPubkeys
      ;

    # This is technically impure, but intended. We need to rekey on the
    # current system due to yubikey availability.
    forceRekeyOnSystem = builtins.extraBuiltins.unsafeCurrentSystem;
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
