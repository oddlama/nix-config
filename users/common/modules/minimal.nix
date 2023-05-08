{lib, ...}: {
  options = {
    home.minimal = lib.mkEnableOption "minimal setup only (e.g. for virtual machines)";
  };
}
