{
  nom = {pkgs, ...}: {
    bee.system = "x86_64-linux";
    bee.pkgs = import inputs.nixos {
      inherit (inputs.nixpkgs) system;
      config.allowUnfree = true;
      overlays = [];
    };
    imports = [
      cell.hardwareProfiles.nom
    ];

	# Disable unnecessary stuff from the nixos defaults.
	services.udisks2.enable = false;
	networking.dhcpcd.enable = false;
	networking.firewall.enable = false;
	security.sudo.enable = false;

	documentation.dev.enable = true;

    # swapDevices = [
    #   {
    #     device = "/.swapfile";
    #     size = 8192; # ~8GB - will be autocreated
    #   }
    # ];
    # Use the systemd-boot EFI boot loader.
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    nix.settings = {
      auto-optimise-store = true;
      allowed-users = ["@wheel"];
      trusted-users = ["root" "@wheel"];
      experimental-features = [
        "flakes"
        "nix-command"
      ];
      accept-flake-config = true;
    };

    # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

    time.timeZone = "Europe/Berlin";

    networking.useDHCP = false;
    networking.interfaces.wlp2s0.useDHCP = true;
    networking.networkmanager.enable = true;
    systemd.services.NetworkManager-wait-online = {
      enable = false;
      serviceConfig.TimeoutSec = 15;
      wantedBy = ["network-online.target"];
    };

    # Configure network proxy if necessary
    # networking.proxy.default = "http://user:password@proxy:port/";
    # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    # Select internationalisation properties.
    i18n.defaultLocale = "C.UTF-8";
    console = {
	  font = "Lat2-Terminus16";
	  keyMap = "de-latin1-nodeadkeys";
    };

    services.sshd.enable = true;

    # Enable sound.
    sound.enable = true;
    sound.mediaKeys.enable = true;

    # Define a user account. Don't forget to set a password with ‘passwd’.
    users = {
      users.lar = {
        shell = pkgs.zsh;
        isNormalUser = true;
        initialPassword = "password123";
        extraGroups = ["wheel"]; # Enable ‘sudo’ for the user.
      };
    };

    # List packages installed in system profile. To search, run:
    # $ nix search wget
    environment.systemPackages = with pkgs; [
      xclip
      tty-share
      alacritty
      element-desktop
      firefox
      chromium
      enpass
      # Office
      libreoffice
      onlyoffice-bin
      beancount
      fava
      direnv
      # Git & Tools
      git
      gh
      gitoxide
      ghq
      # Nix
      # nil # nix language server
      rnix-lsp # nix language server
      alejandra # nix formatter
      # Python
      (python3Full.withPackages (p:
        with p; [
          numpy
          pandas
          ptpython
          requests
          scipy
        ]))
      poetry # python project files
      black # python formatter
    ];

    # Programs configuration
    programs.starship.enable = true;
    programs.nix-ld.enable = true; # quality of life for downloaded programs
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestions.enable = true;
      autosuggestions.async = true;
      syntaxHighlighting.enable = true;
      shellInit = ''
        eval "$(direnv hook zsh)"
      '';
    };
    programs.git = {
      enable = true;
      config = {
        init.defaultBranch = "main";
        core.autocrlf = "input";
        pull.rebase = true;
        rebase.autosquash = true;
        rerere.enable = true;
      };
    };
    programs.ssh = {
      extraConfig = ''
        Host github.com
          User git
          Hostname github.com
          IdentityFile ~/.ssh/lar
        Host gitlab.com
          PreferredAuthentications publickey
          IdentityFile ~/.ssh/lar
      '';
    };

    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    system.stateVersion = "22.11"; # Did you read the comment?
  };
}
