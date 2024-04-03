{config, ...}: let
  inherit
    (config.lib.topology)
    mkInternet
    mkSwitch
    mkRouter
    mkConnection
    mkConnectionRev
    ;
in {
  imports = [
    {
      nodes.fritzbox.interfaces.eth1.network = "home-fritzbox";
    }
  ];

  nodes.internet = mkInternet {};
  nodes.sentinel.interfaces.wan.physicalConnections = [(mkConnectionRev "internet" "*")];

  nodes.fritzbox = mkRouter "FritzBox" {
    info = "FRITZ!Box 7520";
    image = ./images/fritzbox.png;
    interfaceGroups = [
      ["eth1" "eth2" "eth3" "eth4"]
      ["wan1"]
    ];
    connections.eth1 = mkConnection "ward" "wan";
    connections.wan1 = mkConnectionRev "internet" "*";
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
  };
}
