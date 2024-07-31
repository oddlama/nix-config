{
  config,
  globals,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    getExe
    mkAfter
    mkForce
    ;

  hostDomain = globals.domains.me;
  coturnDomain = "coturn.${hostDomain}";
in {
  age.secrets.coturn-password-netbird = {
    generator.script = "alnum";
    group = "turnserver";
    mode = "440";
  };

  networking.firewall.allowedUDPPorts = [
    config.services.coturn.listening-port
    config.services.coturn.alt-listening-port
    config.services.coturn.tls-listening-port
    config.services.coturn.alt-tls-listening-port
  ];
  networking.firewall.allowedTCPPorts = [
    config.services.coturn.listening-port
    config.services.coturn.alt-listening-port
    config.services.coturn.tls-listening-port
    config.services.coturn.alt-tls-listening-port
  ];
  networking.firewall.allowedUDPPortRanges = [
    {
      from = config.services.coturn.min-port;
      to = config.services.coturn.max-port;
    }
  ];
  globals.services.coturn.domain = coturnDomain;

  services.coturn = {
    enable = true;

    realm = coturnDomain;
    lt-cred-mech = true;
    no-cli = true;

    extraConfig = ''
      fingerprint
      user=netbird:@password@
      no-software-attribute
    '';

    cert = "@cert@";
    pkey = "@pkey@";
  };

  systemd.services.coturn = let
    certsDir = config.security.acme.certs.${hostDomain}.directory;
  in {
    preStart = mkAfter ''
      ${getExe pkgs.replace-secret} @password@ ${config.age.secrets.coturn-password-netbird.path} /run/coturn/turnserver.cfg
      ${getExe pkgs.replace-secret} @cert@ <(echo "$CREDENTIALS_DIRECTORY/cert.pem") /run/coturn/turnserver.cfg
      ${getExe pkgs.replace-secret} @pkey@ <(echo "$CREDENTIALS_DIRECTORY/pkey.pem") /run/coturn/turnserver.cfg
    '';
    serviceConfig = {
      LoadCredential = [
        "cert.pem:${certsDir}/fullchain.pem"
        "pkey.pem:${certsDir}/key.pem"
      ];
      Restart = mkForce "always";
      RestartSec = "60"; # Retry every minute
    };
  };

  security.acme.certs.${hostDomain}.postRun = ''
    systemctl restart coturn.service
  '';
}
