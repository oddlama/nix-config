{
  lib,
  config,
  pkgs,
  ...
}: {
  extra.oauth2_proxy = {
    enable = true;
    cookieDomain = config.repo.secrets.local.personalDomain;
    portalDomain = "oauth2.${config.repo.secrets.local.personalDomain}";
    # TODO portal redirect to dashboard (in case someone clicks on kanidm "Web services")
  };

  age.secrets.oauth2-proxy-secret = {
    rekeyFile = ./secrets/oauth2-proxy-secret.age;
    mode = "440";
    group = "oauth2_proxy";
  };

  services.oauth2_proxy = let
    clientId = "web-sentinel";
  in {
    provider = "oidc";
    scope = "openid email";
    loginURL = "https://${config.proxiedDomains.kanidm}/ui/oauth2";
    redeemURL = "https://${config.proxiedDomains.kanidm}/oauth2/token";
    validateURL = "https://${config.proxiedDomains.kanidm}/oauth2/openid/${clientId}/userinfo";
    clientID = clientId;
    keyFile = config.age.secrets.oauth2-proxy-secret.path;
    email.domains = ["*"];

    extraConfig = {
      oidc-issuer-url = "https://${config.proxiedDomains.kanidm}/oauth2/openid/${clientId}";
      skip-provider-button = true;
    };
  };
}
