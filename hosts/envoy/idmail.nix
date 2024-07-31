{
  config,
  globals,
  lib,
  ...
}: let
  primaryDomain = globals.mail.primary;
  idmailDomain = "alias.${primaryDomain}";

  mkRandomSecret = {
    generator.script = "alnum";
    mode = "000";
  };

  mkArgon2id = secret: {
    generator.dependencies = [config.age.secrets.${secret}];
    generator.script = "argon2id";
    mode = "440";
    group = "stalwart-mail";
  };

  shortHash = x: lib.substring 0 16 (builtins.hashString "sha256" "${globals.salt}:${x}");
in {
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/idmail";
      user = "idmail";
      group = "idmail";
      mode = "0700";
    }
  ];

  age.secrets = lib.mergeAttrsList (
    [
      {
        idmail-user-pw_admin = mkRandomSecret;
        idmail-user-hash_admin = mkArgon2id "idmail-user-pw_admin";
      }
    ]
    ++ lib.forEach (lib.attrNames globals.mail.domains) (
      domain: {
        "idmail-mailbox-pw_catch-all@${shortHash domain}" = mkRandomSecret;
        "idmail-mailbox-hash_catch-all@${shortHash domain}" = mkArgon2id "idmail-mailbox-pw_catch-all@${shortHash domain}";
      }
    )
  );

  globals.services.idmail.domain = idmailDomain;
  globals.monitoring.http.idmail = {
    url = "https://${idmailDomain}";
    expectedBodyRegex = "idmail";
    network = "internet";
  };

  #systemd.tmpfiles.settings."50-idmail"."${dataDir}".d = {
  #  user = "idmail";
  #  mode = "0750";
  #};

  services.idmail = {
    enable = true;
    user = "stalwart-mail";
    dataDir = "/var/lib/stalwart-mail";
    provision = {
      enable = true;
      users.admin = {
        admin = true;
        password_hash = "%{file:${config.age.secrets.idmail-user-hash_admin.path}}%";
      };
      domains = lib.flip lib.mapAttrs globals.mail.domains (domain: domainCfg: {
        owner = "admin";
        catch_all = "catch-all@${domain}";
        inherit (domainCfg) public;
      });
      mailboxes = lib.flip lib.mapAttrs' globals.mail.domains (
        domain: _domainCfg:
          lib.nameValuePair "catch-all@${domain}" {
            password_hash = "%{file:${config.age.secrets."idmail-mailbox-hash_catch-all@${shortHash domain}".path}}%";
            owner = "admin";
          }
      );
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
