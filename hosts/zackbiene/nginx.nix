{
  lib,
  config,
  nodeSecrets,
  ...
}: {
  #security.acme.acceptTerms = true;
  #security.acme.defaults.email = "admin+acme@example.com";
  services.nginx = {
    enable = true;

    # Use recommended settings
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    # Only allow PFS-enabled ciphers with AES256
    sslCiphers = "AES256+EECDH:AES256+EDH:!aNULL";
    ## SSL config
    #ssl_protocols TLSv1.2 TLSv1.3;
    #ssl_dhparam /etc/nginx/dhparam.pem;
    #ssl_ciphers EECDH+AESGCM:EDH+AESGCM;
    #ssl_ecdh_curve secp384r1;
    #ssl_session_timeout 10m;
    #ssl_session_cache shared:SSL:10m;
    #ssl_session_tickets off;
    #
    ## OCSP stapling
    #ssl_stapling on;
    #ssl_stapling_verify on;

    virtualHosts = {
      "${nodeSecrets.zigbee2mqtt.domain}" = {
        #forceSSL = true;
        #enableACME = true;
        locations."/" = {
          root = "/var/www";
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [80 443];
}
