{
  type = "nixos";
  system = "x86_64-linux";
  microVmHost = true;
  physicalConnections = {
    "10-lan1" = "LAN 1";
    "10-lan2" = "LAN 2";
  };
}
