# nix eval --impure --json --expr '
#   import ./hosts/sire/tests/eval.nix { flake = builtins.getFlake (toString ./.); }
# '
{ flake }:
let
  inherit (flake.pkgs.x86_64-linux) lib;
  c = flake.nodes.sire.config;
  settings = c.services.antirion.settings;
  domain = "ai.${flake.globals.domains.me}";
  homeVlan = flake.globals.net.home-lan.vlans.home;
  wardProxyIp = flake.globals.net.home-lan.vlans.services.hosts.ward-web-proxy.ipv4;
  adminListen = "${flake.globals.wireguard.proxy-home.hosts.sire.ipv4}:8081";
  oldDomains = map (prefix: "${prefix}.${flake.globals.domains.me}") [
    "llm"
    "tts"
  ];
  adminRoutes = [
    "/ui/"
    "/admin/v1/"
  ];
  proxyCheck =
    name: network: admin:
    let
      proxy = flake.nodes.${name}.config;
      nginx = proxy.services.nginx;
      routes = nginx.virtualHosts.${domain}.locations;
      homeOnly =
        route:
        lib.hasSuffix ''
          allow ${homeVlan.cidrv4};
          allow ${homeVlan.cidrv6};
          deny all;
        '' route.extraConfig;
    in
    lib.all (a: a.assertion) proxy.assertions
    && nginx.virtualHosts.${domain}.forceSSL
    && nginx.virtualHosts.${domain}.useACMEWildcardHost
    && lib.all (old: !(builtins.hasAttr old nginx.virtualHosts)) oldDomains
    && !(nginx.upstreams ? llama-cpp)
    && !(nginx.upstreams ? omnivoice)
    &&
      builtins.attrNames nginx.upstreams.antirion.servers == [
        "${flake.globals.wireguard.${network}.hosts.sire.ipv4}:8080"
      ]
    && routes."/v1/".proxyPass == "http://antirion"
    && routes."/oxr/".proxyPass == "http://antirion"
    && routes."/v1/artifacts/".proxyPass == "http://antirion/oxr/v1/artifacts/"
    && routes."/".return == "404"
    && (
      if admin then
        builtins.attrNames nginx.upstreams.antirion-admin.servers == [ adminListen ]
        && nginx.upstreams.antirion-admin.monitoring.enable
        && lib.all (
          route: routes.${route}.proxyPass == "http://antirion-admin" && homeOnly routes.${route}
        ) adminRoutes
      else
        !(nginx.upstreams ? antirion-admin)
        && lib.all (route: !(routes ? ${route})) adminRoutes
        && lib.all (route: route.proxyPass != "http://antirion-admin") (builtins.attrValues routes)
    )
    &&
      c.networking.nftables.firewall.rules."wg-${network}-node-${name}-to-local".allowedTCPPorts
      == [ 8080 ] ++ lib.optional admin 8081;
  checks = {
    hostAssertions = lib.all (a: a.assertion) c.assertions;
    enabled = c.services.antirion.enable;
    disabledOnMinimal = !flake.nixosConfigurationsMinimal.sire.config.services.antirion.enable;
    listeners = settings.server.listen == "0.0.0.0:8080" && settings.admin.listen == adminListen;
    sharedOrigin =
      settings.auth.admin.public_origin == "https://${domain}"
      && settings.admin.ui.data_plane_url == "https://${domain}"
      && !(settings.security ? cors);
    homeDns =
      lib.elem domain flake.nodes.ward.config.networking.hosts.${wardProxyIp}
      && lib.any (
        rewrite: rewrite.domain == domain && rewrite.answer == wardProxyIp && rewrite.enabled
      ) flake.nodes.ward-adguardhome.config.services.adguardhome.settings.filtering.rewrites;
    backendPorts =
      c.services.llama-cpp.settings.port == 11434
      && c.services.omnivoice.port == 11435
      && c.services.somark-oxr.layoutPort == 11436
      && c.services.somark-oxr.recognitionPort == 11437
      && c.services.somark-oxr.port == 11438;
    backendLoopback =
      c.services.llama-cpp.settings.host == "127.0.0.1"
      && c.services.omnivoice.host == "127.0.0.1"
      && c.services.somark-oxr.listenAddress == "127.0.0.1";
    noUpstreamAuth =
      lib.all (p: p.auth.method == "none") (builtins.attrValues settings.providers)
      && !(c.age.secrets ? llama-cpp-api-keys)
      && !(c.age.secrets ? omnivoice-api-key)
      && !(lib.hasInfix "--api-key" c.systemd.services.llama-cpp.serviceConfig.ExecStart)
      && c.services.omnivoice.apiKeyFile == null
      && c.systemd.services.omnivoice-server.serviceConfig.LoadCredential == [ ]
      && lib.elem "--no-auth" c.services.omnivoice.extraArgs;
    upstreamPaths =
      settings.providers.llamacpp.base_url == "http://127.0.0.1:11434/v1"
      && settings.providers.omnivoice.base_url == "http://127.0.0.1:11435/v1"
      && settings.providers.oxr.base_url == "http://127.0.0.1:11438";
    wyoming =
      c.services.omnivoice.wyoming.enable
      && c.services.omnivoice.wyoming.port == 10200
      && c.services.omnivoice.wyoming.host == flake.globals.wireguard.proxy-home.hosts.sire.ipv4
      &&
        c.networking.nftables.firewall.rules.wg-proxy-home-node-sausebiene-to-local.allowedTCPPorts
        == [ 10200 ];
    persistence = lib.any (
      d: d.directory == "/var/lib/private/antirion" && d.mode == "0700"
    ) c.environment.persistence."/persist".directories;
    wardProxy = proxyCheck "ward-web-proxy" "proxy-home" true;
    sentinelProxy = proxyCheck "sentinel" "proxy-sentinel" false;
    oldServiceNamesRemoved =
      !(flake.globals.services ? llama-cpp) && !(flake.globals.services ? omnivoice);
    operatorKey =
      c.age.secrets.antirion-operator.generator.script == "antirion-api-key"
      && settings.auth.mode == "required"
      && settings.keys.operator.owner == "operator";
  };
in
assert lib.assertMsg (lib.all (value: value) (builtins.attrValues checks))
  "AI gateway wiring checks failed: ${
    lib.concatStringsSep ", " (builtins.attrNames (lib.filterAttrs (_: value: !value) checks))
  }";
checks
