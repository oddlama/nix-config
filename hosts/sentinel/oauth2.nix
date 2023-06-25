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
    loginURL = "https://${config.providedDomains.kanidm}/ui/oauth2";
    redeemURL = "https://${config.providedDomains.kanidm}/oauth2/token";
    validateURL = "https://${config.providedDomains.kanidm}/oauth2/openid/${clientId}/userinfo";
    clientID = clientId;
    keyFile = config.age.secrets.oauth2-proxy-secret.path;
    email.domains = ["*"];

    extraConfig = {
      oidc-issuer-url = "https://${config.providedDomains.kanidm}/oauth2/openid/${clientId}";
      provider-display-name = "Kanidm";
      #skip-provider-button = true;
    };
  };
}
