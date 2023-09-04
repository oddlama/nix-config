{pkgs, ...}: {
  imports = [
    ./fonts.nix
    ./wayland.nix
  ];

  environment.systemPackages = with pkgs; [
    vaapiVdpau
    libvdpau-va-gl
  ];
}
