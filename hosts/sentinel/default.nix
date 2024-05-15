{
  config,
  pkgs,
  ...
}: {
  imports = [
    ../../modules/optional/hardware/hetzner-cloud.nix

    ../../modules
    ../../modules/optional/initrd-ssh.nix
    ../../modules/optional/zfs.nix

    ./acme.nix
    ./coturn.nix
    ./fs.nix
    ./net.nix
    ./oauth2.nix
  ];

  boot.mode = "bios";

  users.groups.acme.members = ["nginx"];
  wireguard.proxy-sentinel.firewallRuleForAll.allowedTCPPorts = [80 443];

  services.nginx.enable = true;
  services.nginx.recommendedSetup = true;

  services.nginx.virtualHosts.${config.repo.secrets.global.domains.me} = {
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
  networking.hosts.${config.wireguard.proxy-sentinel.ipv4} = [config.networking.providedDomains.influxdb];
  meta.telegraf = {
    enable = true;
    scrapeSensors = false;
    influxdb2 = {
      domain = config.networking.providedDomains.influxdb;
      organization = "machines";
      bucket = "telegraf";
      node = "sire-influxdb";
    };
  };
}
