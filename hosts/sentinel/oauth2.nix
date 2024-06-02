{
  config,
  globals,
  nodes,
  ...
}: {
  meta.oauth2-proxy = {
    enable = true;
    cookieDomain = config.repo.secrets.global.domains.me;
    portalDomain = "oauth2.${config.repo.secrets.global.domains.me}";
    # TODO portal redirect to dashboard (in case someone clicks on kanidm "Web services")
  };

  age.secrets.oauth2-cookie-secret = {
    rekeyFile = ./secrets/oauth2-cookie-secret.age;
    mode = "440";
    group = "oauth2-proxy";
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
    group = "oauth2-proxy";
  };

  services.oauth2-proxy = let
    clientId = "web-sentinel";
  in {
    provider = "oidc";
    scope = "openid email";
    loginURL = "https://${globals.services.kanidm.domain}/ui/oauth2";
    redeemURL = "https://${globals.services.kanidm.domain}/oauth2/token";
    validateURL = "https://${globals.services.kanidm.domain}/oauth2/openid/${clientId}/userinfo";
    clientID = clientId;
    email.domains = ["*"];

    extraConfig = {
      oidc-issuer-url = "https://${globals.services.kanidm.domain}/oauth2/openid/${clientId}";
      provider-display-name = "Kanidm";
      #skip-provider-button = true;
    };
  };

  systemd.services.oauth2-proxy.serviceConfig.EnvironmentFile = [
    config.age.secrets.oauth2-cookie-secret.path
    config.age.secrets.oauth2-client-secret.path
  ];
}
