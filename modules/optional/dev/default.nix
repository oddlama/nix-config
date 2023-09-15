{pkgs, ...}: {
  imports = [
    ./documentation.nix
    ./yubikey.nix
  ];

  environment.systemPackages = with pkgs; [
    (gdb.override { enableDebuginfod = true; })
    hotspot
  ];

  environment.enableDebugInfo = true;
  services.nixseparatedebuginfod.enable = true;
}
