{config, ...}: let
  mailDomains = config.repo.secrets.global.domains.mail;
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
        # FIXME: 8e8e1c2eb2f1b8c84f1ef294d2fd746b
        password_hash = "$argon2id$v=19$m=4096,t=3,p=1$c29tZXJhbmRvbXNhbHQ$Hf0sBCqn5Zp5+7LalZNLKhG0exNsXN2M5T+y3QAjpMM";
      };
      # users.test.password_hash = "$argon2id$v=19$m=4096,t=3,p=1$YXJnbGluYXJsZ2luMjRvaQ$DXdfVNRSFS1QSvJo7OmXIhAYYtT/D92Ku16DiJwxn8U";
      # domains."example.com" = {
      #   owner = "admin";
      #   public = true;
      # };
      # mailboxes."me@example.com" = {
      #   password_hash = "$argon2id$v=19$m=4096,t=3,p=1$YXJnbGluYXJsZ2luMjRvaQ$fiD9Bp3KidVI/E+mGudu6+h9XmF9TU9Bx4VGX0PniDE";
      #   owner = "test";
      #   api_token = "%{file:${pkgs.writeText "token" token}}%";
      # };
      # aliases."somealias@example.com" = {
      #   target = "me@example.com";
      #   owner = "me@example.com";
      #   comment = "Used for xyz";
      # };
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
