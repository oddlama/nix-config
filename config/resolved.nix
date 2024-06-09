{
  config,
  lib,
  ...
}: {
  services.resolved = {
    enable = true;
    dnssec = "false"; # wake me up in 20 years when DNSSEC is at least partly working
    fallbackDns = [
      "1.1.1.1"
      "2606:4700:4700::1111"
      "8.8.8.8"
      "2001:4860:4860::8844"
    ];
    llmnr = "false";
    extraConfig = ''
      Domains=~.
      MulticastDNS=true
    '';
  };

  system.nssDatabases.hosts = lib.mkMerge [
    (lib.mkBefore ["mdns_minimal [NOTFOUND=return]"])
    (lib.mkAfter ["mdns"])
  ];

  # Open port 5353 for any interfaces that have MulticastDNS enabled
  networking.nftables.firewall = let
    # Determine all networks that have MulticastDNS enabled
    networksWithMulticast =
      lib.filter
      (n: config.systemd.network.networks.${n}.networkConfig.MulticastDNS or false)
      (lib.attrNames config.systemd.network.networks);

    # Determine all known mac addresses and the corresponding link name
    # based on the renameInterfacesByMac option.
    knownMacs =
      lib.mapAttrs'
      (k: v: lib.nameValuePair v k)
      config.networking.renameInterfacesByMac;
    # A helper that returns the link name for the given mac address,
    # or null if it doesn't exist or the given mac was null.
    linkNameFor = mac:
      if mac == null
      then null
      else knownMacs.${mac} or null;

    # Calls the given function for each network that has MulticastDNS enabled,
    # and collects all non-null values.
    mapNetworks = f: lib.filter (v: v != null) (map f networksWithMulticast);

    # All interfaces on which MulticastDNS is used
    mdnsInterfaces = lib.unique (
      # For each network that is matched by MAC, lookup the link name
      # and if map the definition name to the link name.
      mapNetworks (x: linkNameFor (config.systemd.network.networks.${x}.matchConfig.MACAddress or null))
      # For each network that is matched by name, map the definition
      # name to the link name.
      ++ mapNetworks (x: config.systemd.network.networks.${x}.matchConfig.Name or null)
    );
  in
    lib.mkIf (mdnsInterfaces != []) {
      zones.mdns.interfaces = mdnsInterfaces;
      rules.mdns-to-local = {
        from = ["mdns"];
        to = ["local"];
        allowedUDPPorts = [5353];
      };
    };
}
