{
  lib,
  config,
  pkgs,
  ...
}: {
  extra.oauth2_proxy = {
    enable = true;
    cookieDomain = config.repo.secrets.local.personalDomain;
    authProxyDomain = "sentinel.${config.repo.secrets.local.personalDomain}";
  };

  age.secrets.oauth2-proxy-secret = {
    rekeyFile = ./secrets/oauth2-proxy-secret.age;
    mode = "440";
    group = "oauth2_proxy";
  };

  services.oauth2_proxy = {
    provider = "oidc";
    scope = "openid";
    loginURL = "https://${config.proxiedDomains.kanidm}/ui/oauth2";
    redeemURL = "https://${config.proxiedDomains.kanidm}/oauth2/token";
    validateURL = "https://${config.proxiedDomains.kanidm}/oauth2/openid/web-sentinel/userinfo";
    clientID = "web-sentinel";
    keyFile = config.age.secrets.oauth2-proxy-secret.path;
    email.domains = ["*"];

    extraConfig = {
      # TODO good idea? would fail when offline
      # TODO autorestart after 30 minutes, infinite times.
      oidc-issuer-url = "https://${config.proxiedDomains.kanidm}/oauth2/openid/web-sentinel";
      skip-provider-button = true;

      # TODO away
      show-debug-on-error = true;
    };
  };
}
