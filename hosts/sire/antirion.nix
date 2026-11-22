{
  config,
  globals,
  lib,
  minimal,
  ...
}:
let
  domain = "ai.${globals.domains.me}";
  port = 8080;
  adminPort = 8081;
  proxies = {
    ward-web-proxy = "proxy-home";
    sentinel = "proxy-sentinel";
  };
  # The only frontend that routes the admin console, restricted to the home VLAN.
  adminProxy = "ward-web-proxy";
  proxyAddress = name: network: globals.wireguard.${network}.hosts.${name}.ipv4;
  ownAddress = network: globals.wireguard.${network}.hosts.${config.node.name}.ipv4;
  # Not on loopback or the LAN: only the admin frontend can reach this.
  adminListen = "${ownAddress proxies.${adminProxy}}:${toString adminPort}";
  localProvider = backendPort: prefix: {
    type = "openai_compatible";
    base_url = "http://127.0.0.1:${toString backendPort}${prefix}";
    auth.method = "none";
  };
in
{
  config = lib.mkIf (!minimal) {
    # The operator is an API-only identity, not an admin-console login. Add one
    # identity/key per friend here; never distribute this key as a shared token.
    age.secrets.antirion-operator.generator.script = "antirion-api-key";

    services.antirion = {
      enable = true;
      settings = {
        server.listen = "0.0.0.0:${toString port}";
        admin.listen = adminListen;
        # The console shares the data plane's origin; cookie-authenticated
        # writes are only accepted from exactly this origin.
        auth.admin.public_origin = "https://${domain}";
        admin.ui.data_plane_url = "https://${domain}";

        providers = {
          llamacpp = (localProvider config.services.llama-cpp.settings.port "/v1") // {
            capabilities.operations = [ "generate" ];
          };
          omnivoice = (localProvider config.services.omnivoice.port "/v1") // {
            capabilities.operations = [ "speech" ];
          };
          # Passthrough already carries /v1 in the forwarded path.
          oxr = localProvider config.services.somark-oxr.port "";
        };
        deployments = {
          qwen = {
            provider = "llamacpp";
            model = config.services.llama-cpp.settings.alias;
          };
          omnivoice = {
            provider = "omnivoice";
            model = config.services.omnivoice.servedModelId;
          };
        };
        models = {
          ${config.services.llama-cpp.settings.alias}.target = "qwen";
          ${config.services.omnivoice.servedModelId}.target = "omnivoice";
        };
        api.passthrough.oxr = {
          path_prefix = "/oxr";
          provider = "oxr";
          # Async polling is POST /v1/parse/async_check; artifacts need GET.
          methods = [
            "GET"
            "POST"
          ];
        };

        security = {
          limits.max_body = "128MiB";
          # Also resolves admin-plane client addresses for sessions and audit.
          client_ip.trusted_proxies = lib.mapAttrsToList (
            name: network: "${proxyAddress name network}/32"
          ) proxies;
        };
        policies = {
          # A gateway-wide ceiling in addition to each key's own allowance.
          limits.concurrent = {
            unit = "concurrency";
            limit = 8;
          };
          resilience.timeouts = {
            response_headers = "15m";
            ttft = "5m";
            attempt = "15m";
            deadline = "15m";
          };
        };
        users.operator = {
          kind = "service";
          display_name = "Personal API access";
        };
        keys.operator = {
          secret._secret = config.age.secrets.antirion-operator.path;
          owner = "operator";
          models = [
            config.services.llama-cpp.settings.alias
            config.services.omnivoice.servedModelId
          ];
          # Passthrough uses provider permissions, not model permissions.
          providers = [
            "llamacpp"
            "omnivoice"
            "oxr"
          ];
          policies.limits = {
            rpm = {
              unit = "requests";
              limit = 30;
              per = "1m";
            };
            concurrent = {
              unit = "concurrency";
              limit = 2;
            };
          };
        };
      };
    };

    # Accounting history and the spool are not disposable cache data.
    environment.persistence."/persist".directories = [
      {
        directory = "/var/lib/private/antirion";
        mode = "0700";
      }
    ];

    globals.services.antirion.domain = domain;
    globals.wireguard = lib.mapAttrs' (
      name: network:
      lib.nameValuePair network {
        hosts.${config.node.name}.firewallRuleForNode.${name}.allowedTCPPorts = [
          port
        ]
        ++ lib.optional (name == adminProxy) adminPort;
      }
    ) proxies;

    nodes = lib.mapAttrs (name: network: {
      services.nginx =
        lib.recursiveUpdate
          (import ./antirion-proxy.nix {
            inherit domain;
            upstream = "${ownAddress network}:${toString port}";
            admin =
              if name == adminProxy then
                {
                  upstream = adminListen;
                  allow = [
                    globals.net.home-lan.vlans.home.cidrv4
                    globals.net.home-lan.vlans.home.cidrv6
                  ];
                }
              else
                null;
          })
          {
            upstreams = {
              antirion.monitoring = {
                enable = true;
                path = "/-/readyz";
              };
            }
            // lib.optionalAttrs (name == adminProxy) {
              antirion-admin.monitoring = {
                enable = true;
                path = "/-/readyz";
              };
            };
            virtualHosts.${domain} = {
              forceSSL = true;
              useACMEWildcardHost = true;
            };
          };
    }) proxies;
  };
}
