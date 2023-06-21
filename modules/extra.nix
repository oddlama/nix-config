{
  config,
  lib,
  nodePath,
  ...
}: let
  inherit
    (lib)
    assertMsg
    filter
    flip
    genAttrs
    hasInfix
    head
    mapAttrs
    mapAttrs'
    mdDoc
    mkIf
    mkOption
    nameValuePair
    optionals
    removeSuffix
    types
    ;
in {
  options.extra = {
    acme.wildcardDomains = mkOption {
      default = [];
      example = ["example.org"];
      type = types.listOf types.str;
      description = mdDoc ''
        All domains for which a wildcard certificate will be generated.
        This will define the given `security.acme.certs` and set `extraDomainNames` correctly,
        but does not fill any options such as credentials or dnsProvider. These have to be set
        individually for each cert by the user or via `security.acme.defaults`.
      '';
    };

    nginx.proxiedDomains = mkOption {
      default = {};
      description = mdDoc "Simplified reverse proxy setup.";
      type = types.attrsOf (types.submodule (submod: {
        options = {
          domain = mkOption {
            type = types.str;
            description = mdDoc "The public domain for the virtual host.";
          };

          upstream = mkOption {
            type = types.str;
            description = mdDoc "The upstream server to which requests are forwarded.";
          };

          scheme = mkOption {
            type = types.str;
            default = "http";
            description = mdDoc "The scheme to use when connecting to upstream.";
          };

          useACMEHost = mkOption {
            type = types.str;
            default = config.lib.extra.matchingWildcardCert submod.config.domain;
            description = mdDoc "The acme host certificate to use for the virtual host.";
          };
        };
      }));
    };
  };

  config = {
    lib.extra = {
      # For a given domain, this searches for a matching wildcard acme domain that
      # would include the given domain. If no such domain is defined in
      # extra.acme.wildcardDomains, an assertion is triggered.
      matchingWildcardCert = domain: let
        matchingCerts =
          filter
          (x: !hasInfix "." (removeSuffix ".${x}" domain))
          config.extra.acme.wildcardDomains;
      in
        assert assertMsg (matchingCerts != []) "No wildcard certificate was defined that matches ${domain}";
          head matchingCerts;
    };

    security.acme.certs = genAttrs config.extra.acme.wildcardDomains (domain: {
      extraDomainNames = ["*.${domain}"];
    });

    age.secrets = mkIf config.services.nginx.enable {
      "dhparams.pem" = {
        rekeyFile = nodePath + "/secrets/dhparams.pem.age";
        generator = "dhparams";
        mode = "440";
        group = "nginx";
      };
    };

    # Sensible defaults for nginx
    services.nginx = mkIf config.services.nginx.enable {
      recommendedBrotliSettings = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      # SSL config
      sslCiphers = "EECDH+AESGCM:EDH+AESGCM:!aNULL";
      sslDhparam = config.age.secrets."dhparams.pem".path;
      commonHttpConfig = ''
        error_log syslog:server=unix:/dev/log;
        access_log syslog:server=unix:/dev/log;
        ssl_ecdh_curve secp384r1;

        # Enable HTTP Strict Transport Security (HSTS)
        add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";

        # Minimize information leaked to other domains
        add_header Referrer-Policy "origin-when-cross-origin";

        add_header X-XSS-Protection "1; mode=block";
        add_header X-Frame-Options "DENY";
        add_header X-Content-Type-Options "nosniff";
      '';

      upstreams =
        flip mapAttrs config.extra.nginx.proxiedDomains
        (name: cfg: {
          servers."${cfg.upstream}" = {};
          extraConfig = ''
            zone ${name} 64k;
            keepalive 2;
          '';
        });

      virtualHosts =
        flip mapAttrs' config.extra.nginx.proxiedDomains
        (name: cfg:
          nameValuePair cfg.domain {
            forceSSL = true;
            inherit (cfg) useACMEHost;
            locations."/".proxyPass = "${cfg.scheme}://${name}";
          });
    };

    networking.firewall.allowedTCPPorts = optionals config.services.nginx.enable [80 443];
  };
}
