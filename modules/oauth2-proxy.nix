{
  lib,
  config,
  pkgs,
  ...
}: let
  inherit
    (lib)
    concatStringsSep
    flip
    mapAttrs
    mdDoc
    mkEnableOption
    mkIf
    mkOption
    optionalString
    types
    ;

  cfg = config.extra.oauth2_proxy;
in {
  options.extra.oauth2_proxy = {
    enable = mkEnableOption (mdDoc "oauth2 proxy");

    cookieDomain = mkOption {
      type = types.str;
      description = mdDoc "The domain under which to store the credential cookie, and to which redirects will be allowed.";
    };

    portalDomain = mkOption {
      type = types.str;
      description = mdDoc "A domain on which to setup the oauth2 callback.";
    };
  };

  options.services.nginx.virtualHosts = mkOption {
    type = types.attrsOf (types.submodule ({
      name,
      config,
      ...
    }: {
      options.oauth2 = {
        enable = mkEnableOption (mdDoc "access protection of this resource using oauth2_proxy.");
        allowedGroups = mkOption {
          type = types.listOf types.str;
          default = [];
          description = mdDoc ''
            A list of groups that are allowed to access this resource, or the
            empty list to allow any authenticated client.
          '';
        };
      };
      config = mkIf config.oauth2.enable {
        locations."/".extraConfig = ''
          auth_request /oauth2/auth;
          error_page 401 = /oauth2/sign_in;

          # pass information via X-User and X-Email headers to backend,
          # requires running with --set-xauthrequest flag
          auth_request_set $user   $upstream_http_x_auth_request_user;
          auth_request_set $email  $upstream_http_x_auth_request_email;
          proxy_set_header X-User  $user;
          proxy_set_header X-Email $email;

          # if you enabled --cookie-refresh, this is needed for it to work with auth_request
          auth_request_set $auth_cookie $upstream_http_set_cookie;
          add_header Set-Cookie $auth_cookie;
        '';

        locations."/oauth2/" = {
          proxyPass = "http://oauth2_proxy";
          extraConfig = ''
            proxy_set_header X-Scheme                $scheme;
            proxy_set_header X-Auth-Request-Redirect $scheme://$host$request_uri;
          '';
        };

        locations."= /oauth2/auth" = {
          proxyPass =
            "http://oauth2_proxy/oauth2/auth"
            + optionalString (config.oauth2.allowedGroups != [])
            "?allowed_groups=${concatStringsSep "," config.oauth2.allowedGroups}";
          extraConfig = ''
            internal;

            proxy_set_header X-Scheme         $scheme;
            # nginx auth_request includes headers but not body
            proxy_set_header Content-Length   "";
            proxy_pass_request_body           off;
          '';
        };
      };
    }));
  };

  config = mkIf cfg.enable {
    services.oauth2_proxy = {
      enable = true;

      cookie.domain = ".${cfg.cookieDomain}";
      cookie.secure = true;
      # FIXME disabled because of errors. My closest guess is that this
      # reuses refresh tokens but kanidm forbids that. Not sure though.
      #cookie.refresh = "5m";
      cookie.expire = "30m";

      reverseProxy = true;
      httpAddress = "unix:///run/oauth2_proxy/oauth2_proxy.sock";
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

    systemd.services.oauth2_proxy.serviceConfig = {
      RuntimeDirectory = "oauth2_proxy";
      RuntimeDirectoryMode = "0750";
      UMask = "007"; # TODO remove once https://github.com/oauth2-proxy/oauth2-proxy/issues/2141 is fixed
    };

    users.groups.oauth2_proxy.members = ["nginx"];

    services.nginx = {
      upstreams.oauth2_proxy = {
        servers."unix:/run/oauth2_proxy/oauth2_proxy.sock" = {};
        extraConfig = ''
          zone oauth2_proxy 64k;
          keepalive 2;
        '';
      };

      virtualHosts.${cfg.portalDomain} = {
        forceSSL = true;
        useACMEHost = config.lib.extra.matchingWildcardCert cfg.portalDomain;
        oauth2.enable = true;
        locations."/".proxyPass = "http://oauth2_proxy";
      };
    };
  };
}
