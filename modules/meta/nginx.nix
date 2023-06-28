{
  config,
  lib,
  nodePath,
  ...
}: let
  inherit
    (lib)
    mdDoc
    mkIf
    mkOption
    types
    ;
in {
  options.services.nginx.virtualHosts = mkOption {
    type = types.attrsOf (types.submodule ({config, ...}: {
      options.recommendedSecurityHeaders = mkOption {
        type = types.bool;
        default = true;
        description = mdDoc ''Whether to add additional security headers to the "/" location.'';
      };
      config = mkIf config.recommendedSecurityHeaders {
        locations."/".extraConfig = ''
          # Enable HTTP Strict Transport Security (HSTS)
          add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";

          # Minimize information leaked to other domains
          add_header Referrer-Policy "origin-when-cross-origin";

          add_header X-XSS-Protection "1; mode=block";
          add_header X-Frame-Options "DENY";
          add_header X-Content-Type-Options "nosniff";
        '';
      };
    }));
  };

  config = mkIf config.services.nginx.enable {
    age.secrets."dhparams.pem" = {
      rekeyFile = nodePath + "/secrets/dhparams.pem.age";
      generator = "dhparams";
      mode = "440";
      group = "nginx";
    };

    # Sensible defaults for nginx
    services.nginx = {
      recommendedBrotliSettings = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      # SSL config
      sslCiphers = "EECDH+AESGCM:EDH+AESGCM:!aNULL";
      sslDhparam = config.age.secrets."dhparams.pem".path;
      commonHttpConfig = ''
        log_format json_combined escape=json '{'
          '"time": $msec,'
          '"remote_addr":"$remote_addr",'
          '"status":$status,'
          '"method":"$request_method",'
          '"host":"$host",'
          '"uri":"$request_uri",'
          '"request_size":$request_length,'
          '"response_size":$body_bytes_sent,'
          '"response_time":$request_time,'
          '"referrer":"$http_referer",'
          '"user_agent":"$http_user_agent"'
        '}';
        error_log syslog:server=unix:/dev/log,nohostname;
        access_log syslog:server=unix:/dev/log,nohostname json_combined;
        ssl_ecdh_curve secp384r1;
      '';
    };

    networking.firewall.allowedTCPPorts = [80 443];
  };
}
