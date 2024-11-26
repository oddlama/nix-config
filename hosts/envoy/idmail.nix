{
  inputs,
  config,
  globals,
  lib,
  ...
}:
let
  primaryDomain = globals.mail.primary;
  idmailDomain = "alias.${primaryDomain}";

  mkRandomSecret = {
    generator.script = "alnum";
    mode = "000";
  };

  mkArgon2id = secret: {
    generator.dependencies = [ config.age.secrets.${secret} ];
    generator.script = "argon2id";
    mode = "440";
    group = "stalwart-mail";
  };
in
{
  environment.persistence."/persist".directories = [
    {
      directory = config.services.idmail.dataDir;
      user = "stalwart-mail";
      group = "stalwart-mail";
      mode = "4770";
    }
  ];

  age.secrets = {
    idmail-user-pw_admin = mkRandomSecret;
    idmail-user-hash_admin = mkArgon2id "idmail-user-pw_admin";
    idmail-mailbox-pw_catch-all = mkRandomSecret;
    idmail-mailbox-hash_catch-all = mkArgon2id "idmail-mailbox-pw_catch-all";
  };

  globals.services.idmail.domain = idmailDomain;
  globals.monitoring.http.idmail = {
    url = "https://${idmailDomain}";
    expectedBodyRegex = "idmail";
    network = "internet";
  };

  services.idmail = {
    package = inputs.idmail.packages."x86_64-linux".default;
    enable = true;
    # Stalwart will change permissions due to SQLite implementation.
    # Therefore, run as stalwart-mail since we don't allow reading
    # stalwarts folder anyway (sandboxing is on).
    user = "stalwart-mail";
    provision = {
      enable = true;
      users.admin = {
        admin = true;
        password_hash = "%{file:${config.age.secrets.idmail-user-hash_admin.path}}%";
      };
      domains = lib.flip lib.mapAttrs globals.mail.domains (
        _domain: domainCfg: {
          owner = "admin";
          catch_all = "catch-all@${primaryDomain}";
          inherit (domainCfg) public;
        }
      );
      mailboxes = lib.flip lib.mapAttrs' globals.mail.domains (
        _domain: _domainCfg:
        lib.nameValuePair "catch-all@${primaryDomain}" {
          password_hash = "%{file:${config.age.secrets.idmail-mailbox-hash_catch-all.path}}%";
          owner = "admin";
        }
      );
      # XXX: create mailboxes for git@ vaultwarden@ and simultaneously alias them to the catch all for a send only mail.
    };
  };
  systemd.services.idmail.serviceConfig.RestartSec = "60"; # Retry every minute

  services.nginx = {
    upstreams.idmail = {
      servers."127.0.0.1:3000" = { };
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
