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
  proxies = {
    ward-web-proxy = "proxy-home";
    sentinel = "proxy-sentinel";
  };
  proxyAddress = name: network: globals.wireguard.${network}.hosts.${name}.ipv4;
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
        admin.listen = "127.0.0.1:8081";
        auth.admin.public_origin = "http://localhost:8081";
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
          # Allow the private admin console, reached through an SSH tunnel.
          cors.data.allowed_origins = [ "http://localhost:8081" ];
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
        hosts.${config.node.name}.firewallRuleForNode.${name}.allowedTCPPorts = [ port ];
      }
    ) proxies;

    nodes = lib.mapAttrs (_: network: {
      services.nginx =
        lib.recursiveUpdate
          (import ./antirion-proxy.nix {
            inherit domain;
            upstream = "${globals.wireguard.${network}.hosts.${config.node.name}.ipv4}:${toString port}";
          })
          {
            upstreams.antirion.monitoring = {
              enable = true;
              path = "/-/readyz";
            };
            virtualHosts.${domain} = {
              forceSSL = true;
              useACMEWildcardHost = true;
            };
          };
    }) proxies;
  };
}
