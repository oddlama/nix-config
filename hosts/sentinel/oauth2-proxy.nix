{
  config,
  lib,
  nodes,
  ...
}: let
  inherit (config.repo.secrets.local) acme personalDomain;
  authDomain = "auth.${personalDomain}";
in {
  networking.domain = personalDomain;

  # Contains OAUTH2_PROXY_CLIENT_SECRET=...
  #rekey.secrets.grafana-secret-key = {
  #  file = ./secrets/oauth2-proxy-client-secret.age;
  #  mode = "440";
  #  group = "oauth2_proxy";
  #};

  services.oauth2_proxy = {
    enable = true;
    cookie.secure = true;
    cookie.httpOnly = false;
    email.domains = ["*"];
    provider = "oidc";
    scope = "openid email";
    loginURL = "https://${authDomain}/ui/oauth2";
    redeemURL = "https://${authDomain}/oauth2/token";
    validateURL = "https://${authDomain}/oauth2/openid/grafana/userinfo";
    clientID = "oauth2-proxy";
    clientSecret = "";
    #keyFile = config.rekey.secrets.oauth2-proxy-client-secret.path;
    reverseProxy = true;
    extraConfig.skip-provider-button = true;
    setXauthrequest = true;
  };

  # Apply oauth by default to all locations
  services.nginx.virtualHosts = lib.genAttrs config.services.oauth2_proxy.nginx.virtualHosts (_: {
    extraConfig = ''
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
    locations."/oauth2/".extraConfig = "auth_request off;";
    locations."/oauth2/auth".extraConfig = "auth_request off;";
  });
}
