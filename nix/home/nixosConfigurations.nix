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

    time.timeZone = "Europe/Berlin";

    # Select internationalisation properties.
    i18n.defaultLocale = "C.UTF-8";
    console = {
      keyMap = "de-latin1-nodeadkeys";
    };

    # Enable the OpenSSH daemon.
    services.openssh = {
      enable = true;
      passwordAuthentication = false;
      kbdInteractiveAuthentication = false;
      permitRootLogin = "yes";
      hostKeys = [
        {
          path = "/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];
    };

    # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

    # Configure network proxy if necessary
    # networking.proxy.default = "http://user:password@proxy:port/";
    # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    services.sshd.enable = true;

    # Enable sound.
    sound.enable = true;
    sound.mediaKeys.enable = true;

    # Define a user account. Don't forget to set a password with ‘passwd’.
    users = {
      users.root = {
        initialHashedPassword = "$6$EBo/CaxB.dQoq2W8$lo2b5vKgJlLPdGGhEqa08q3Irf1Zd1PcFBCwJOrG8lqjwbABkn1DEhrMh1P3ezwnww2HusUBuZGDSMa4nvSQg1";
        openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5Uq+CDy5Pmt3If5M6d8K/Q7HArU6sZ7sgoj3T521Wm"];
      };
      users.myuser = {
        isNormalUser = true;
        shell = pkgs.zsh;
        extraGroups = ["wheel" "audio" "video"]; # Enable ‘sudo’ for the user.
        packages = with pkgs; [
          firefox
          thunderbird
        ];
      };
    };

    # List packages installed in system profile. To search, run:
    # $ nix search wget
    environment.systemPackages = with pkgs; [
      kitty
      firefox
      direnv
      # Git & Tools
      git
      # Nix
      # nil # nix language server
      rnix-lsp # nix language server
      alejandra # nix formatter
      # Python
      black # python formatter
    ];

    # Programs configuration
    programs.neovim.enable = true;
    programs.neovim.viAlias = true;
    environment.variables.EDITOR = "nvim";

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
        pull.rebase = true;
      };
    };
    #programs.ssh = {
    #  extraConfig = ''
    #    Host github.com
    #      User git
    #      Hostname github.com
    #      IdentityFile ~/.ssh/lar
    #    Host gitlab.com
    #      PreferredAuthentications publickey
    #      IdentityFile ~/.ssh/lar
    #  '';
    #};

    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    system.stateVersion = "22.11"; # Did you read the comment?
  };
}
