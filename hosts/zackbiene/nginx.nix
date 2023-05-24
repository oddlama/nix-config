{
  lib,
  config,
  ...
}: {
  rekey.secrets."selfcert.crt" = {
    file = ./secrets/selfcert.crt.age;
    mode = "440";
    group = "nginx";
  };
  rekey.secrets."selfcert.key" = {
    file = ./secrets/selfcert.key.age;
    mode = "440";
    group = "nginx";
  };
  rekey.secrets."dhparams.pem" = {
    file = ./secrets/dhparams.pem.age;
    mode = "440";
    group = "nginx";
  };

  #security.acme.acceptTerms = true;
  #security.acme.defaults.email = "admin+acme@example.com";
  services.nginx = {
    enable = true;

    recommendedBrotliSettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    # SSL config
    sslCiphers = "EECDH+AESGCM:EDH+AESGCM:!aNULL";
    sslDhparam = config.rekey.secrets."dhparams.pem".path;
    commonHttpConfig = ''
      error_log syslog:server=unix:/dev/log;
      access_log syslog:server=unix:/dev/log;
      ssl_ecdh_curve secp384r1;
    '';
  };

  networking.firewall.allowedTCPPorts = [80 443];
}
