# nix eval --impure --json --expr '
#   import ./hosts/sire/tests/eval.nix { flake = builtins.getFlake (toString ./.); }
# '
{ flake }:
let
  inherit (flake.pkgs.x86_64-linux) lib;
  c = flake.nodes.sire.config;
  settings = c.services.antirion.settings;
  domain = "ai.${flake.globals.domains.me}";
  oldDomains = map (prefix: "${prefix}.${flake.globals.domains.me}") [
    "llm"
    "tts"
  ];
  proxyCheck =
    name: network:
    let
      proxy = flake.nodes.${name}.config;
      nginx = proxy.services.nginx;
      routes = nginx.virtualHosts.${domain}.locations;
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
    &&
      c.networking.nftables.firewall.rules."wg-${network}-node-${name}-to-local".allowedTCPPorts
      == [ 8080 ];
  checks = {
    hostAssertions = lib.all (a: a.assertion) c.assertions;
    enabled = c.services.antirion.enable;
    disabledOnMinimal = !flake.nixosConfigurationsMinimal.sire.config.services.antirion.enable;
    listeners = settings.server.listen == "0.0.0.0:8080" && settings.admin.listen == "127.0.0.1:8081";
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
    wardProxy = proxyCheck "ward-web-proxy" "proxy-home";
    sentinelProxy = proxyCheck "sentinel" "proxy-sentinel";
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
