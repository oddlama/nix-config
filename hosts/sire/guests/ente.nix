{
  config,
  globals,
  lib,
  pkgs,
  ...
}:
# NOTE: To increase storage for all users:
#  $ runuser -u ente -- psql
#  ente => UPDATE subscriptions SET storage = 6597069766656;
let
  enteAccountsDomain = "accounts.photos.${globals.domains.me}";
  enteAlbumsDomain = "albums.photos.${globals.domains.me}";
  enteApiDomain = "api.photos.${globals.domains.me}";
  enteCastDomain = "cast.photos.${globals.domains.me}";
  entePhotosDomain = "photos.${globals.domains.me}";
  s3Domain = "s3.photos.${globals.domains.me}";

  proxyConfig = remoteAddr: nginxExtraConfig: {
    upstreams.museum = {
      servers."${remoteAddr}:8080" = { };
      extraConfig = ''
        zone museum 64k;
        keepalive 20;
      '';
      monitoring = {
        enable = true;
        path = "/ping";
        expectedStatus = 200;
      };
    };

    upstreams.minio = {
      servers."${remoteAddr}:9000" = { };
      extraConfig = ''
        zone minio 64k;
        keepalive 20;
      '';
      monitoring = {
        enable = true;
        path = "/minio/health/live";
        expectedStatus = 200;
      };
    };

    virtualHosts = {
      ${enteApiDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        locations."/".proxyPass = "http://museum";
        extraConfig = ''
          client_max_body_size 4M;
          ${nginxExtraConfig}
        '';
      };
      ${s3Domain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        locations."/".proxyPass = "http://minio";
        extraConfig = ''
          client_max_body_size 32M;
          proxy_buffering off;
          proxy_request_buffering off;
          ${nginxExtraConfig}
        '';
      };
    }
    //
      lib.genAttrs
        [
          enteAccountsDomain
          enteAlbumsDomain
          enteCastDomain
          entePhotosDomain
        ]
        (_domain: {
          useACMEWildcardHost = true;
          extraConfig = nginxExtraConfig;
        });
  };
in
{
  wireguard.proxy-sentinel = {
    client.via = "sentinel";
    firewallRuleForNode.sentinel.allowedTCPPorts = [
      8080
      9000
    ];
  };

  wireguard.proxy-home = {
    client.via = "ward";
    firewallRuleForNode.ward-web-proxy.allowedTCPPorts = [
      8080
      9000
    ];
  };

  globals.services.ente.domain = entePhotosDomain;
  # FIXME: also monitor from internal network
  globals.monitoring.http.ente = {
    url = "https://${entePhotosDomain}";
    expectedBodyRegex = "Ente Photos";
    network = "internet";
  };

  fileSystems."/storage".neededForBoot = true;
  environment.persistence."/storage".directories = [
    {
      directory = "/var/lib/minio";
      user = "minio";
      group = "minio";
      mode = "0750";
    }
  ];

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/ente";
      user = "ente";
      group = "ente";
      mode = "0750";
    }
  ];

  # NOTE: don't use the root user for access. In this case it doesn't matter
  # since the whole minio server is only for ente anyway, but it would be a
  # good practice.
  age.secrets.minio-access-key = {
    generator.script = "alnum";
    mode = "440";
    group = "ente";
  };
  age.secrets.minio-secret-key = {
    generator.script = "alnum";
    mode = "440";
    group = "ente";
  };
  age.secrets.minio-root-credentials = {
    generator.dependencies = [
      config.age.secrets.minio-access-key
      config.age.secrets.minio-secret-key
    ];
    generator.script =
      {
        lib,
        decrypt,
        deps,
        ...
      }:
      ''
        echo -n "MINIO_ROOT_USER="
        ${decrypt} ${lib.escapeShellArg (builtins.elemAt deps 0).file}
        echo -n "MINIO_ROOT_PASSWORD="
        ${decrypt} ${lib.escapeShellArg (builtins.elemAt deps 1).file}
      '';
    mode = "440";
    group = "minio";
  };

  # base64 (url)
  age.secrets.ente-jwt = {
    generator.script =
      { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -base64 32 | tr -d '\n' | tr '/+' '_-'";
    mode = "440";
    group = "ente";
  };
  # base64 (standard)
  age.secrets.ente-encryption-key = {
    generator.script = "base64";
    mode = "440";
    group = "ente";
  };
  # base64 (standard)
  age.secrets.ente-hash-key = {
    generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -base64 64 | tr -d '\n'";
    mode = "440";
    group = "ente";
  };
  age.secrets.ente-smtp-password = {
    generator.script = "alnum";
    mode = "440";
    group = "ente";
  };

  services.minio = {
    enable = true;
    rootCredentialsFile = config.age.secrets.minio-root-credentials.path;
  };
  systemd.services.minio = {
    environment.MINIO_SERVER_URL = "https://${s3Domain}";
    postStart = ''
      # Wait until minio is up
      ${lib.getExe pkgs.curl} --retry 5 --retry-connrefused --fail --no-progress-meter -o /dev/null "http://localhost:9000/minio/health/live"

      # Make sure bucket exists
      mkdir -p ${lib.escapeShellArg config.services.minio.dataDir}/ente
    '';
  };

  systemd.services.ente.after = [ "minio.service" ];
  services.ente.api = {
    enable = true;
    enableLocalDB = true;
    domain = enteApiDomain;
    settings = {
      apps = {
        accounts = "https://${enteAccountsDomain}";
        cast = "https://${enteCastDomain}";
        public-albums = "https://${enteAlbumsDomain}";
      };

      webauthn = {
        rpid = enteAccountsDomain;
        rporigins = [ "https://${enteAccountsDomain}" ];
      };

      # FIXME: blocked on https://github.com/ente-io/ente/issues/5958
      # smtp = {
      #   host = config.repo.secrets.local.ente.mail.host;
      #   port = 465;
      #   email = config.repo.secrets.local.ente.mail.from;
      #   username = config.repo.secrets.local.ente.mail.user;
      #   password._secret = config.age.secrets.ente-smtp-password.path;
      # };

      s3 = {
        use_path_style_urls = true;
        b2-eu-cen = {
          endpoint = "https://${s3Domain}";
          region = "us-east-1";
          bucket = "ente";
          key._secret = config.age.secrets.minio-access-key.path;
          secret._secret = config.age.secrets.minio-secret-key.path;
        };
      };

      jwt.secret._secret = config.age.secrets.ente-jwt.path;
      key = {
        encryption._secret = config.age.secrets.ente-encryption-key.path;
        hash._secret = config.age.secrets.ente-hash-key.path;
      };
    };
  };

  # NOTE: services.ente.web is configured separately on both proxy servers!
  nodes.sentinel.services.nginx =
    proxyConfig globals.wireguard.proxy-sentinel.hosts.${config.node.name}.ipv4
      "";
  nodes.ward-web-proxy.services.nginx =
    proxyConfig globals.wireguard.proxy-home.hosts.${config.node.name}.ipv4
      ''
        allow ${globals.net.home-lan.vlans.home.cidrv4};
        allow ${globals.net.home-lan.vlans.home.cidrv6};
        # Firezone traffic
        allow ${globals.net.home-lan.vlans.services.hosts.ward.ipv4};
        allow ${globals.net.home-lan.vlans.services.hosts.ward.ipv6};
        deny all;
      '';
}
