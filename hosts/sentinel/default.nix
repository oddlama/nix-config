{
  config,
  globals,
  pkgs,
  ...
}: {
  imports = [
    ../../config
    ../../config/hardware/hetzner-cloud.nix
    ../../config/optional/initrd-ssh.nix
    ../../config/optional/zfs.nix

    ./acme.nix
    ./coturn.nix
    ./fs.nix
    ./net.nix
    ./oauth2.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  boot.mode = "bios";

  wireguard.proxy-sentinel.firewallRuleForAll.allowedTCPPorts = [80 443];

  users.groups.acme.members = ["nginx"];
  services.nginx.enable = true;
  services.nginx.recommendedSetup = true;

  services.nginx.virtualHosts.${globals.domains.me} = {
    forceSSL = true;
    useACMEWildcardHost = true;
    locations."/".root = pkgs.runCommand "index.html" {} ''
      mkdir -p $out
      cat > $out/index.html <<EOF
      <html>
        <body>Not empty soon TM. Until then please go here: <a href="https://github.com/oddlama">oddlama</a></body>
      </html>
      EOF
    '';
  };

  meta.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  # Connect safely via wireguard to skip authentication
  networking.hosts.${config.wireguard.proxy-sentinel.ipv4} = [globals.services.influxdb.domain];
  meta.telegraf = {
    enable = true;
    scrapeSensors = false;
    influxdb2 = {
      inherit (globals.services.influxdb) domain;
      organization = "machines";
      bucket = "telegraf";
      node = "sire-influxdb";
    };

    # This node shall monitor the infrastructure
    availableMonitoringNetworks = ["internet"];
  };
}
