{
  type = "nixos";
  system = "x86_64-linux";
  microVmHost = true;
  physicalConnections = {
    "10-lan" = "LAN";
    "10-wan" = "WAN";
  };
}
