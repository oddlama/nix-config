{
  lib,
  config,
  pkgs,
  nodes,
  ...
}: {
  meta.oauth2_proxy = {
    enable = true;
    cookieDomain = config.repo.secrets.local.personalDomain;
    portalDomain = "oauth2.${config.repo.secrets.local.personalDomain}";
    # TODO portal redirect to dashboard (in case someone clicks on kanidm "Web services")
  };

  age.secrets.oauth2-cookie-secret = {
    rekeyFile = ./secrets/oauth2-cookie-secret.age;
    mode = "440";
    group = "oauth2_proxy";
  };

  # Mirror the original oauth2 secret, but prepend OAUTH2_PROXY_CLIENT_SECRET=
  # so it can be used as an EnvironmentFile
  age.secrets.oauth2-client-secret = {
    generator.dependencies = [
      nodes.ward-kanidm.config.age.secrets.kanidm-oauth2-web-sentinel
    ];
    generator.script = {
      lib,
      decrypt,
      deps,
      ...
    }: ''
      echo -n "OAUTH2_PROXY_CLIENT_SECRET="
      ${decrypt} ${lib.escapeShellArg (lib.head deps).file}
    '';
    mode = "440";
    group = "oauth2_proxy";
  };

  services.oauth2_proxy = let
    clientId = "web-sentinel";
  in {
    provider = "oidc";
    scope = "openid email";
    loginURL = "https://${config.networking.providedDomains.kanidm}/ui/oauth2";
    redeemURL = "https://${config.networking.providedDomains.kanidm}/oauth2/token";
    validateURL = "https://${config.networking.providedDomains.kanidm}/oauth2/openid/${clientId}/userinfo";
    clientID = clientId;
    keyFile = config.age.secrets.oauth2-cookie-secret.path;
    email.domains = ["*"];

    extraConfig = {
      oidc-issuer-url = "https://${config.networking.providedDomains.kanidm}/oauth2/openid/${clientId}";
      provider-display-name = "Kanidm";
      #skip-provider-button = true;
    };
  };
}
