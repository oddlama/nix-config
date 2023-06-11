{
  config,
  lib,
  nodes,
  pkgs,
  ...
}: let
  inherit (config.repo.secrets.local) acme personalDomain;
in {
  users.groups.acme.members = ["caddy"];

  # TODO assertions = lib.flip lib.mapAttrsToList config.users.users
  # TODO   (name: user: {
  # TODO     assertion = user.uid != null;
  # TODO     message = "non-deterministic uid detected for: ${name}";
  # TODO   });

  age.secrets.loki-basic-auth-hashes = {
    rekeyFile = ./secrets/loki-basic-auth-hashes.age;
    generator = {
      dependencies = [
        # TODO allow defining these from other nodes like nodes.sentinel.age.secrets....dependenices = [];
        nodes.ward.config.age.secrets.loki-basic-auth-password
        nodes.ward-grafana.config.age.secrets.loki-basic-auth-password
      ];
      script = {
        pkgs,
        lib,
        decrypt,
        deps,
        ...
      }:
        lib.flip lib.concatMapStrings deps ({
          name,
          host,
          file,
        }: ''
          echo " -> Aggregating [32m"${lib.escapeShellArg host}":[m[33m"${lib.escapeShellArg name}"[m" >&2
          echo -n ${lib.escapeShellArg host}" "
          ${decrypt} ${lib.escapeShellArg file} \
            | ${pkgs.caddy}/bin/caddy hash-password --algorithm bcrypt \
            || die "Failure while aggregating caddy basic auth hashes"
        '');
    };
    mode = "440";
    group = "caddy";
  };

  services.caddy = let
    authDomain = nodes.ward-kanidm.config.services.kanidm.serverSettings.domain;
    authPort = lib.last (lib.splitString ":" nodes.ward-kanidm.config.services.kanidm.serverSettings.bindaddress);
    grafanaDomain = nodes.ward-grafana.config.services.grafana.settings.server.domain;
    grafanaPort = toString nodes.ward-grafana.config.services.grafana.settings.server.http_port;
    lokiDomain = "loki.${personalDomain}";
    lokiPort = toString nodes.ward-loki.config.services.loki.configuration.server.http_listen_port;
  in {
    enable = true;
    package = pkgs.caddy.withPackages {
      plugins = [
        {
          name = "github.com/greenpau/caddy-security";
          version = "v1.1.18";
        }
      ];
      vendorHash = "sha256-RqSXQihtY5+ACaMo7bLdhu1A+qcraexb1W/Ia+aUF1k";
    };

    # globalConfig = ''
    #   # servers {
    #   #   metrics
    #   # }

    #   order authenticate before respond
    #   order authorize before basicauth

    #   security {
    #     oauth identity provider generic {
    #       realm generic
    #       driver generic
    #       client_id {env.GENERIC_CLIENT_ID}
    #       client_secret {env.GENERIC_CLIENT_SECRET}
    #       scopes openid email profile
    #       base_auth_url https://${authDomain}/ui/oauth2
    #       metadata_url https://${authDomain}/oauth2/openid/{env.GENERIC_CLIENT_ID}/.well-known/openid-configuration
    #     }

    #     authentication portal myportal {
    #       crypto default token lifetime 3600
    #       crypto key sign-verify {env.JWT_SHARED_KEY}
    #       enable identity provider generic
    #       cookie domain myfiosgateway.com
    #       ui {
    #         links {
    #           "My Identity" "/whoami" icon "las la-user"
    #         }
    #       }

    #       transform user {
    #         match realm generic
    #         action add role authp/user
    #         ui link "File Server" https://assetq.myfiosgateway.com:8443/ icon "las la-star"
    #       }

    #       transform user {
    #         match realm generic
    #         match email greenpau@contoso.com
    #         action add role authp/admin
    #       }
    #     }

    #     authorization policy mypolicy {
    #       set auth url https://auth.myfiosgateway.com:8443/oauth2/generic
    #       crypto key verify {env.JWT_SHARED_KEY}
    #       allow roles authp/admin authp/user
    #       validate bearer header
    #       inject headers with claims
    #     }
    #   }
    # '';

    # TODO move subconfigs to the relevant hosts instead.
    # -> have something like merged config nodes.<name>....
    # -> needs to be in a way that doesn't trigger infinite recursion

    virtualHosts.${authDomain} = {
      useACMEHost = config.lib.extra.matchingWildcardCert authDomain;
      extraConfig = ''
        encode zstd gzip
        reverse_proxy {
          to https://${nodes.ward-kanidm.config.extra.wireguard.proxy-sentinel.ipv4}:${authPort}
          transport http {
            tls_insecure_skip_verify
          }
        }
      '';
    };

    virtualHosts.${grafanaDomain} = {
      useACMEHost = config.lib.extra.matchingWildcardCert grafanaDomain;
      extraConfig = ''
        encode zstd gzip
        reverse_proxy {
          to http://${nodes.ward-grafana.config.extra.wireguard.proxy-sentinel.ipv4}:${grafanaPort}
        }
      '';
    };

    virtualHosts.${lokiDomain} = {
      useACMEHost = config.lib.extra.matchingWildcardCert lokiDomain;
      extraConfig = ''
        encode zstd gzip
        skip_log
        basicauth {
          import ${config.age.secrets.loki-basic-auth-hashes.path}
        }
        reverse_proxy {
          to http://${nodes.ward-loki.config.extra.wireguard.proxy-sentinel.ipv4}:${lokiPort}
        }
      '';
    };
  };
}
