{
  config,
  globals,
  nodes,
  ...
}:
let
  linkwardenDomain = "links.${globals.domains.me}";
in
{
  microvm.mem = 1024 * 4;
  microvm.vcpu = 8;

  # Mirror the original oauth2 secret
  age.secrets.linkwarden-oauth2-client-secret = {
    inherit (nodes.ward-kanidm.config.age.secrets.kanidm-oauth2-linkwarden) rekeyFile;
    mode = "440";
    group = "linkwarden";
  };

  globals.wireguard.proxy-sentinel.hosts.${config.node.name}.firewallRuleForNode.sentinel.allowedTCPPorts =
    [ 3010 ];
  globals.wireguard.proxy-home.hosts.${config.node.name}.firewallRuleForNode.ward-web-proxy.allowedTCPPorts =
    [ 3010 ];

  globals.services.linkwarden.domain = linkwardenDomain;
  globals.monitoring.http.linkwarden = {
    url = "https://${linkwardenDomain}";
    expectedBodyRegex = "<title>linkwardenFiNE";
    network = "internet";
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/linkwarden";
      user = "linkwarden";
      group = "linkwarden";
      mode = "0750";
    }
  ];

  # services.linkwarden = {
  #   enable = true;
  # };
  #
  # nodes.sentinel = {
  #   services.nginx = {
  #     upstreams.linkwarden = {
  #       servers."${globals.wireguard.proxy-sentinel.hosts.${config.node.name}.ipv4}:3010" = { };
  #       extraConfig = ''
  #         zone linkwarden 64k;
  #         keepalive 2;
  #       '';
  #       monitoring = {
  #         enable = true;
  #         expectedBodyRegex = "<title>linkwardenFiNE";
  #       };
  #     };
  #     virtualHosts.${linkwardenDomain} = {
  #       forceSSL = true;
  #       useACMEWildcardHost = true;
  #       locations."/" = {
  #         proxyPass = "http://linkwarden";
  #         proxyWebsockets = true;
  #       };
  #       extraConfig = ''
  #         client_max_body_size 128M;
  #       '';
  #     };
  #   };
  # };
  #
  # nodes.ward-web-proxy = {
  #   services.nginx = {
  #     upstreams.linkwarden = {
  #       servers."${globals.wireguard.proxy-home.hosts.${config.node.name}.ipv4}:3010" = { };
  #       extraConfig = ''
  #         zone linkwarden 64k;
  #         keepalive 2;
  #       '';
  #       monitoring = {
  #         enable = true;
  #         expectedBodyRegex = "<title>linkwardenFiNE";
  #       };
  #     };
  #     virtualHosts.${linkwardenDomain} = {
  #       forceSSL = true;
  #       useACMEWildcardHost = true;
  #       locations."/" = {
  #         proxyPass = "http://linkwarden";
  #         proxyWebsockets = true;
  #       };
  #       extraConfig = ''
  #         client_max_body_size 128M;
  #         allow ${globals.net.home-lan.vlans.home.cidrv4};
  #         allow ${globals.net.home-lan.vlans.home.cidrv6};
  #         # Firezone traffic
  #         allow ${globals.net.home-lan.vlans.services.hosts.ward.ipv4};
  #         allow ${globals.net.home-lan.vlans.services.hosts.ward.ipv6};
  #         deny all;
  #       '';
  #     };
  #   };
  # };

  backups.storageBoxes.dusk = {
    subuser = "linkwarden";
    paths = [ "/var/lib/linkwarden" ];
  };
}
