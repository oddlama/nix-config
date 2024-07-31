{
  config,
  globals,
  lib,
  ...
}: let
  mailDomains = globals.domains.mail;
  primaryDomain = mailDomains.primary;
  idmailDomain = "alias.${primaryDomain}";
in {
  # Not needed, we store stuff in stalwart's directory
  #environment.persistence."/persist".directories = [
  #  {
  #    directory = "/var/lib/idmail";
  #    user = "idmail";
  #    group = "idmail";
  #    mode = "0700";
  #  }
  #];

  age.secrets.idmail-admin-hash = {
    rekeyFile = ./secrets/idmail-admin-hash.age;
    mode = "440";
    group = "stalwart-mail";
  };

  globals.services.idmail.domain = idmailDomain;
  globals.monitoring.http.idmail = {
    url = "https://${idmailDomain}";
    expectedBodyRegex = "idmail";
    network = "internet";
  };

  services.idmail = {
    enable = true;
    user = "stalwart-mail";
    dataDir = "/var/lib/stalwart-mail";
    provision = {
      enable = true;
      users.admin = {
        admin = true;
        password_hash = "%{file:${config.age.secrets.idmail-admin-hash.path}}%";
      };
      domains = lib.genAttrs mailDomains.all (_: {
        owner = "admin";
        public = true;
      });
    };
  };
  systemd.services.idmail.serviceConfig.RestartSec = "60"; # Retry every minute

  services.nginx = {
    upstreams.idmail = {
      servers."127.0.0.1:3000" = {};
      extraConfig = ''
        zone idmail 64k;
        keepalive 2;
      '';
    };
    virtualHosts.${idmailDomain} = {
      forceSSL = true;
      useACMEWildcardHost = true;
      locations."/" = {
        proxyPass = "http://idmail";
        proxyWebsockets = true;
      };
    };
  };
}
