{lib, ...}: {
  boot.loader = {
    grub = {
      enable = true;
      efiSupport = false;
    };
    timeout = lib.mkDefault 2;
  };
  console.earlySetup = true;
}
