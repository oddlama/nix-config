{
  lib,
  pkgs,
  config,
  utils,
  ...
}: let
  excludePackages = with pkgs; [fira];
in {
  environment.pathsToLink = [
    "/share/backgrounds"
    "/share/cosmic"
  ];
  environment.systemPackages =
    utils.removePackagesByName (
      with pkgs;
        [
          adwaita-icon-theme
          alsa-utils
          cosmic-applets
          cosmic-applibrary
          cosmic-bg
          (cosmic-comp.override {
            # avoid PATH pollution of system action keybinds (Xwayland handled below)
            useXWayland = false;
          })
          cosmic-edit
          cosmic-files
          cosmic-greeter
          cosmic-icons
          cosmic-launcher
          cosmic-notifications
          cosmic-osd
          cosmic-panel
          cosmic-randr
          cosmic-screenshot
          cosmic-session
          cosmic-settings
          cosmic-settings-daemon
          cosmic-term
          cosmic-wallpapers
          cosmic-workspaces-epoch
          hicolor-icon-theme
          playerctl
          pop-icon-theme
          pop-launcher
          xdg-user-dirs
          xwayland
        ]
        ++ lib.optionals config.services.flatpak.enable [
          cosmic-store
        ]
    )
    excludePackages;

  # xdg portal packages and config
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-cosmic
      xdg-desktop-portal-gtk
    ];
    configPackages = lib.mkDefault (
      with pkgs; [
        xdg-desktop-portal-cosmic
      ]
    );
  };

  # fonts
  fonts.packages =
    utils.removePackagesByName (with pkgs; [
      fira
    ])
    excludePackages;

  # required features
  # hardware.${
  #   if lib.versionAtLeast lib.version "24.11"
  #   then "graphics"
  #   else "opengl"
  # }.enable =
  #   true;
  # services.libinput.enable = true;
  # xdg.mime.enable = true;
  # xdg.icons.enable = true;

  # optional features
  # hardware.bluetooth.enable = lib.mkDefault true;
  services.acpid.enable = lib.mkDefault true;
  # services.pipewire = {
  #   enable = lib.mkDefault true;
  #   alsa.enable = lib.mkDefault true;
  #   pulse.enable = lib.mkDefault true;
  # };
  services.gvfs.enable = lib.mkDefault true;
  # networking.networkmanager.enable = lib.mkDefault true;
  services.gnome.gnome-keyring.enable = lib.mkDefault true;

  # general graphical session features
  # programs.dconf.enable = lib.mkDefault true;
  #
  # required dbus services
  services.accounts-daemon.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = lib.mkDefault (!config.hardware.system76.power-daemon.enable);
  security.polkit.enable = true;
  security.rtkit.enable = true;

  # session packages
  services.displayManager.sessionPackages = with pkgs; [cosmic-session];
  systemd.packages = with pkgs; [cosmic-session];
  # TODO: remove when upstream has XDG autostart support
  systemd.user.targets.cosmic-session = {
    wants = ["xdg-desktop-autostart.target"];
    before = ["xdg-desktop-autostart.target"];
  };

  # required for screen locker
  security.pam.services.cosmic-greeter = {};

  nix.settings.substituters = [
    "https://cosmic.cachix.org/"
  ];
  nix.settings.trusted-public-keys = [
    "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
  ];

  # module diagnostics
  warnings =
    lib.optional
    (
      lib.elem pkgs.cosmic-files excludePackages
      && !(lib.elem pkgs.cosmic-session excludePackages)
    )
    ''
      The COSMIC session may fail to initialise with the `cosmic-files` package excluded via
      `excludePackages`.

      Please do one of the following:
        1. Remove `cosmic-files` from `excludePackages`.
        2. Add `cosmic-session` (in addition to `cosmic-files`) to
           `excludePackages` and ensure whatever session starter/manager you are
           using is appropriately set up.
    '';
  assertions = [
    {
      assertion = lib.elem "libcosmic-app-hook" (
        lib.map (
          drv: lib.optionalString (lib.isDerivation drv) (lib.getName drv)
        )
        pkgs.cosmic-comp.nativeBuildInputs
      );
      message = ''
        It looks like the provided `pkgs` to the NixOS COSMIC module is not usable for a working COSMIC
        desktop environment.

        If you are erroneously passing in `pkgs` to `specialArgs` somewhere in your system configuration,
        this is is often unnecessary and has unintended consequences for all NixOS modules. Please either
        remove that in favor of configuring the NixOS `pkgs` instance via `nixpkgs.config` and
        `nixpkgs.overlays`.

        If you must instantiate your own `pkgs`, then please include the overlay from the NixOS COSMIC flake
        when instantiating `pkgs` and be aware that the `nixpkgs.config` and `nixpkgs.overlays` options will
        not function for any NixOS modules.

        Note that the COSMIC packages in Nixpkgs are still largely broken as of 2024-10-16 and will not be
        usable for having a fully functional COSMIC desktop environment. The overlay is therefore necessary.
      '';
    }
  ];
}
