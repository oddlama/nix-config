{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    yubikey-manager
    yubikey-personalization
    age-plugin-yubikey
  ];
  services.udev.packages = with pkgs; [
    yubikey-personalization
    libu2f-host
  ];
  services.pcscd.enable = true;
}
