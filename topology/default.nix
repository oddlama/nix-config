{config, ...}: let
  inherit
    (config.lib.topology)
    mkInternet
    mkDevice
    mkSwitch
    mkRouter
    mkConnection
    ;
in {
  imports = [
    {
      nodes.fritzbox.interfaces.eth1.network = "home-fritzbox";
    }
  ];

  nodes.internet = mkInternet {
    connections = [
      (mkConnection "sentinel" "wan")
      (mkConnection "fritzbox" "wan1")
    ];
  };

  nodes.fritzbox = mkRouter "FritzBox" {
    info = "FRITZ!Box 7520";
    image = ./images/fritzbox.png;
    interfaceGroups = [
      ["eth1" "eth2" "eth3" "eth4"]
      ["wan1"]
    ];
    connections.eth1 = mkConnection "ward" "wan";
    interfaces.eth1.addresses = ["192.168.178.1"];
  };

  networks.home-fritzbox = {
    name = "Home Fritzbox";
    cidrv4 = "192.168.178.0/24";
  };

  networks.ward-kea.name = "Home LAN";
  nodes.switch-attic = mkSwitch "Switch Attic" {
    info = "D-Link DGS-1016D";
    image = ./images/dlink-dgs1016d.png;
    interfaceGroups = [["eth1" "eth2" "eth3" "eth4" "eth5" "eth6"]];
    connections.eth1 = mkConnection "ward" "lan-self";
    connections.eth2 = mkConnection "sire" "lan-self";
  };

  nodes.switch-bedroom-1 = mkSwitch "Switch Bedroom 1" {
    info = "D-Link DGS-105";
    image = ./images/dlink-dgs105.png;
    interfaceGroups = [["eth1" "eth2" "eth3" "eth4" "eth5"]];
    connections.eth1 = mkConnection "switch-attic" "eth3";
    connections.eth2 = mkConnection "kroma" "lan1";
    connections.eth3 = mkConnection "nom" "lan1";
    connections.eth4 = mkConnection "switch-livingroom" "eth1";
  };

  nodes.switch-livingroom = mkSwitch "Switch Livingroom" {
    info = "D-Link DGS-105";
    image = ./images/dlink-dgs105.png;
    interfaceGroups = [["eth1" "eth2" "eth3" "eth4" "eth5"]];
    connections.eth2 = mkConnection "tv-livingroom" "eth1";
  };

  nodes.tv-livingroom = mkDevice "Livingroom TV" {
    # TODO info
    # image = ./images/epson-xp-7100.png;
    interfaces.eth1 = {};
  };

  nodes.ruckus-ap = mkSwitch "Wi-Fi AP" {
    info = "Ruckus R500";
    image = ./images/ruckus-r500.png;
    interfaceGroups = [["eth1" "wifi"]];
    connections.eth1 = mkConnection "switch-attic" "eth4";
  };

  nodes.printer = mkDevice "Printer Attic" {
    info = "Epson XP-7100";
    image = ./images/epson-xp-7100.png;
    connections.eth1 = mkConnection "switch-attic" "eth5";
  };

  nodes.dect-repeater = mkSwitch "DECT Repeater" {
    info = "FRITZ!Box 7490";
    image = ./images/fritzbox.png;
    interfaceGroups = [
      ["eth1" "eth2" "eth3" "eth4"]
    ];
    connections.eth1 = mkConnection "switch-attic" "eth6";
  };

  nodes.wallbox = mkDevice "Wallbox" {
    info = "Mennekes Amtron";
    image = ./images/mennekes-wallbox.png;
    connections.eth1 = mkConnection "dect-repeater" "eth2";
  };
}
