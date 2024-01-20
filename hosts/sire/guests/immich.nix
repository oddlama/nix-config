{
  pkgs,
  config,
  nodes,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  immichDomain = "immich.${sentinelCfg.repo.secrets.local.personalDomain}";

  ipImmichMachineLearning = "10.89.0.10";
  ipImmichMicroservices = "10.89.0.11";
  ipImmichPostgres = "10.89.0.12";
  ipImmichRedis = "10.89.0.13";
  ipImmichServer = "10.89.0.14";

  version = "v1.93.3";
  environment = {
    DB_DATABASE_NAME = "immich";
    DB_HOSTNAME = ipImmichPostgres;
    DB_PASSWORD_FILE = config.age.secrets.postgres_password.path;
    DB_USERNAME = "postgres";
    IMMICH_VERSION = "${version}";
    UPLOAD_LOCATION = upload_folder;
    IMMICH_SERVER_URL = "http://${ipImmichServer}:3001/";
    IMMICH_MACHINE_LEARNING_URL = "http://${ipImmichMachineLearning}:3003";
    REDIS_HOSTNAME = ipImmichRedis;
  };

  upload_folder = "/storage/immich";
  pgdata_folder = "/persist/immich/pgdata";
  model_folder = "/state/immich/modeldata";

  serviceConfig = {
    serviceConfig.Restart = "always";
    after = ["podman-network-immich-default.service"];
    requires = ["podman-network-immich-default.service"];
    partOf = ["podman-compose-immich-root.target"];
    wantedBy = ["podman-compose-immich-root.target"];
  };
in {
  microvm.mem = 1024 * 8;
  microvm.vcpu = 20;

  meta.wireguard-proxy.sentinel.allowedTCPPorts = [2283];

  nodes.sentinel = {
    networking.providedDomains.immich = immichDomain;

    services.nginx = {
      upstreams.immich = {
        servers."${config.meta.wireguard.proxy-sentinel.ipv4}:2283" = {};
        extraConfig = ''
          zone immich 64k;
          keepalive 2;
        '';
      };
      virtualHosts.${immichDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        oauth2.enable = true;
        oauth2.allowedGroups = ["access_immich"];
        locations."/" = {
          proxyPass = "http://immich";
          proxyWebsockets = true;
        };
      };
    };
  };

  systemd.tmpfiles.settings = {
    "10-immich" = {
      ${upload_folder}.d = {
        mode = "0770";
      };
      ${pgdata_folder}.d = {
        mode = "0770";
      };
      ${model_folder}.d = {
        mode = "0770";
      };
    };
  };

  age.secrets.postgres_password.generator.script = "alnum";

  # Runtime
  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
    dockerCompat = true;
  };
  virtualisation.oci-containers.backend = "podman";

  # Containers
  virtualisation.oci-containers.containers."immich_machine_learning" = {
    image = "ghcr.io/immich-app/immich-machine-learning:${version}";
    inherit environment;
    volumes = [
      "${model_folder}:/cache:rw"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=immich-machine-learning"
      "--network=immich-default"
      "--ip=${ipImmichMachineLearning}"
    ];
  };
  systemd.services."podman-immich_machine_learning" = serviceConfig;
  virtualisation.oci-containers.containers."immich_microservices" = {
    image = "ghcr.io/immich-app/immich-server:${version}";
    inherit environment;
    volumes = [
      "${config.age.secrets.postgres_password.path}:${config.age.secrets.postgres_password.path}:ro"
      "/etc/localtime:/etc/localtime:ro"
      "${upload_folder}:/usr/src/app/upload:rw"
    ];
    cmd = ["start.sh" "microservices"];
    dependsOn = [
      "immich_postgres"
      "immich_redis"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=immich-microservices"
      "--network=immich-default"
      "--ip=${ipImmichMicroservices}"
    ];
  };
  systemd.services."podman-immich_microservices" =
    serviceConfig
    // {
      unitConfig.UpheldBy = [
        "podman-immich_postgres.service"
        "podman-immich_redis.service"
      ];
    };
  virtualisation.oci-containers.containers."immich_postgres" = {
    image = "tensorchord/pgvecto-rs:pg14-v0.1.11@sha256:0335a1a22f8c5dd1b697f14f079934f5152eaaa216c09b61e293be285491f8ee";
    environment = {
      POSTGRES_DB = environment.DB_DATABASE_NAME;
      POSTGRES_PASSWORD_FILE = environment.DB_PASSWORD_FILE;
      POSTGRES_USER = environment.DB_USERNAME;
    };
    volumes = [
      "${config.age.secrets.postgres_password.path}:${config.age.secrets.postgres_password.path}:ro"
      "${pgdata_folder}:/var/lib/postgresql/data:rw"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=immich_postgres"
      "--network=immich-default"
      "--ip=${ipImmichPostgres}"
    ];
  };
  systemd.services."podman-immich_postgres" = serviceConfig;
  virtualisation.oci-containers.containers."immich_redis" = {
    image = "redis:6.2-alpine@sha256:c5a607fb6e1bb15d32bbcf14db22787d19e428d59e31a5da67511b49bb0f1ccc";
    log-driver = "journald";
    extraOptions = [
      "--network-alias=immich_redis"
      "--network=immich-default"
      "--ip=${ipImmichRedis}"
    ];
  };
  systemd.services."podman-immich_redis" = serviceConfig;
  virtualisation.oci-containers.containers."immich_server" = {
    image = "ghcr.io/immich-app/immich-server:${version}";
    inherit environment;
    volumes = [
      "${config.age.secrets.postgres_password.path}:${config.age.secrets.postgres_password.path}:ro"
      "/etc/localtime:/etc/localtime:ro"
      "${upload_folder}:/usr/src/app/upload:rw"
    ];
    ports = [
      "2283:3001/tcp"
    ];
    cmd = ["start.sh" "immich"];
    dependsOn = [
      "immich_postgres"
      "immich_redis"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=immich-server"
      "--network=immich-default"
      "--ip=${ipImmichServer}"
    ];
  };
  systemd.services."podman-immich_server" =
    serviceConfig
    // {
      unitConfig.UpheldBy = [
        "podman-immich_postgres.service"
        "podman-immich_redis.service"
      ];
    };

  # Networks
  systemd.services."podman-network-immich-default" = {
    path = [pkgs.podman];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "${pkgs.podman}/bin/podman network rm -f immich-default";
    };
    script = ''
      podman network inspect immich-default || podman network create immich-default --opt isolate=true --subnet=10.89.0.0/24
    '';
    partOf = ["podman-compose-immich-root.target"];
    wantedBy = ["podman-compose-immich-root.target"];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."podman-compose-immich-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    wantedBy = ["multi-user.target"];
  };
}
