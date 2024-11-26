{ pkgs, ... }:
{
  # XXX: Do NOT enable "Use discrete GPU" when running on nvidia by default.
  # Otherwise the xorg server will crash big time (no logs). After some gdb
  # debugging the culprit seems to be the x11 nvidia driver (nvidia_drv.so),
  # which doesn't like it when you set one of the following env variables:
  # (not entirely sure which one)
  #   DRI_PRIME=1
  #   __NV_PRIME_RENDER_OFFLOAD=1
  #   __VK_LAYER_NV_optimus=NVIDIA_only
  #   __GLX_VENDOR_LIBRARY_NAME=nvidia
  # See also: https://github.com/PrismLauncher/PrismLauncher/issues/1628, https://bbs.archlinux.org/viewtopic.php?id=272161
  home.packages = with pkgs; [
    prismlauncher
  ];

  home.persistence."/persist".directories = [
    ".local/share/PrismLauncher"
  ];
}
