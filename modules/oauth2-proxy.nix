{
  lib,
  config,
  ...
}: let
  inherit
    (lib)
    concatStringsSep
    mkDefault
    mkEnableOption
    mkIf
    mkOption
    optionalString
    types
    ;

  cfg = config.meta.oauth2-proxy;
in {
  options.meta.oauth2-proxy = {
    enable = mkEnableOption "oauth2 proxy";

    cookieDomain = mkOption {
      type = types.str;
      description = "The domain under which to store the credential cookie, and to which redirects will be allowed.";
    };

    portalDomain = mkOption {
      type = types.str;
      description = "A domain on which to setup the oauth2 callback.";
    };
  };

  options.services.nginx.virtualHosts = mkOption {
    type = types.attrsOf (types.submodule ({config, ...}: {
      options.oauth2 = {
        enable = mkEnableOption "access protection of this resource using oauth2-proxy.";
        allowedGroups = mkOption {
          type = types.listOf types.str;
          default = [];
          description = ''
            A list of groups that are allowed to access this resource, or the
            empty list to allow any authenticated client.
          '';
        };
        X-User = mkOption {
          type = types.str;
          default = "$upstream_http_x_auth_request_preferred_username";
          description = "The variable to set as X-User";
        };
        X-Email = mkOption {
          type = types.str;
          default = "$upstream_http_x_auth_request_email";
          description = "The variable to set as X-User";
        };
      };
      options.locations = mkOption {
        type = types.attrsOf (types.submodule (locationSubmod: {
          options.setOauth2Headers = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to add oauth2 specific headers to this location. Only takes effect is oauth2 is actually enabled on the parent vhost.";
          };
          config = mkIf (config.oauth2.enable && locationSubmod.config.setOauth2Headers) {
            extraConfig = ''
              proxy_set_header X-User  $user;
              proxy_set_header X-Email $email;
              add_header Set-Cookie $auth_cookie;
            '';
          };
        }));
      };
      config = mkIf config.oauth2.enable {
        extraConfig = ''
          auth_request /oauth2/auth;
          error_page 401 = @redirectToAuth2ProxyLogin;

          # set variables that can be used in locations.<name>.extraConfig
          # pass information via X-User and X-Email headers to backend,
          # requires running with --set-xauthrequest flag
          auth_request_set $user  ${config.oauth2.X-User};
          auth_request_set $email ${config.oauth2.X-Email};
          # if you enabled --cookie-refresh, this is needed for it to work with auth_request
          auth_request_set $auth_cookie $upstream_http_set_cookie;
        '';

        locations."@redirectToAuth2ProxyLogin" = {
          # FIXME: allow referring to another node for the portaldomain
          setOauth2Headers = false;
          return = "307 https://${cfg.portalDomain}/oauth2/start?rd=$scheme://$host$request_uri";
          extraConfig = ''
            auth_request off;
          '';
        };

        locations."= /oauth2/auth" = {
          setOauth2Headers = false;
          proxyPass =
            "http://oauth2-proxy/oauth2/auth"
            + optionalString (config.oauth2.allowedGroups != [])
            "?allowed_groups=${concatStringsSep "," config.oauth2.allowedGroups}";
          extraConfig = ''
            auth_request off;
            internal;

            proxy_set_header X-Scheme       $scheme;
            # nginx auth_request includes headers but not body
            proxy_set_header Content-Length "";
            proxy_pass_request_body         off;
          '';
        };
      };
    }));
  };

  config = mkIf cfg.enable {
    services.oauth2-proxy = {
      enable = true;

      cookie.domain = ".${cfg.cookieDomain}";
      cookie.secure = true;
      # FIXME disabled because of errors. My closest guess is that this
      # reuses refresh tokens but kanidm forbids that. Not sure though.
      #cookie.refresh = "5m";
      cookie.expire = "30m";
      cookie.secret = mkDefault null;

      clientSecret = mkDefault null;
      reverseProxy = true;
      httpAddress = "unix:///run/oauth2-proxy/oauth2-proxy.sock";
      redirectURL = "https://${cfg.portalDomain}/oauth2/callback";
      setXauthrequest = true;

      extraConfig = {
        # Enable PKCE
        code-challenge-method = "S256";
        # Share the cookie with all subpages
        whitelist-domain = ".${cfg.cookieDomain}";
        set-authorization-header = true;
        pass-access-token = true;
        skip-jwt-bearer-tokens = true;
        upstream = "static://202";
      };
    };

    systemd.services.oauth2-proxy.serviceConfig = {
      RuntimeDirectory = "oauth2-proxy";
      RuntimeDirectoryMode = "0750";
      UMask = "007"; # TODO remove once https://github.com/oauth2-proxy/oauth2-proxy/issues/2141 is fixed
      RestartSec = "60"; # Retry every minute
    };

    users.groups.oauth2-proxy.members = ["nginx"];

    services.nginx = {
      upstreams.oauth2-proxy = {
        servers."unix:/run/oauth2-proxy/oauth2-proxy.sock" = {};
        extraConfig = ''
          zone oauth2-proxy 64k;
          keepalive 2;
        '';
      };

      virtualHosts.${cfg.portalDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        locations."/".proxyPass = "http://oauth2-proxy";

        locations."/oauth2/" = {
          proxyPass = "http://oauth2-proxy";
          extraConfig = ''
            proxy_set_header X-Scheme                $scheme;
            proxy_set_header X-Auth-Request-Redirect $scheme://$host$request_uri;
          '';
        };
      };
    };
  };
}
