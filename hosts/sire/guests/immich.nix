{
  config,
  globals,
  nodes,
  pkgs,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  wardWebProxyCfg = nodes.ward-web-proxy.config;
  immichDomain = "immich.${globals.domains.me}";

  ipImmichMachineLearning = "10.89.0.10";
  ipImmichPostgres = "10.89.0.12";
  ipImmichRedis = "10.89.0.13";
  ipImmichServer = "10.89.0.14";
  configFile = pkgs.writeText "immich.config.json" (
    builtins.toJSON {
      ffmpeg = {
        accel = "disabled";
        bframes = -1;
        cqMode = "auto";
        crf = 23;
        gopSize = 0;
        maxBitrate = "0";
        npl = 0;
        preset = "ultrafast";
        refs = 0;
        targetAudioCodec = "aac";
        targetResolution = "720";
        targetVideoCodec = "h264";
        temporalAQ = false;
        threads = 0;
        tonemap = "hable";
        transcode = "required";
        twoPass = false;
      };
      job = {
        backgroundTask.concurrency = 5;
        faceDetection.concurrency = 10;
        library.concurrency = 5;
        metadataExtraction.concurrency = 10;
        migration.concurrency = 5;
        search.concurrency = 5;
        sidecar.concurrency = 5;
        smartSearch.concurrency = 10;
        thumbnailGeneration.concurrency = 10;
        videoConversion.concurrency = 5;
      };
      library.scan = {
        enabled = true;
        cronExpression = "0 0 * * *";
      };
      logging = {
        enabled = true;
        level = "log";
      };
      machineLearning = {
        clip = {
          enabled = true;
          modelName = "ViT-B-32__openai";
        };
        enabled = true;
        facialRecognition = {
          enabled = true;
          maxDistance = 0.45;
          minFaces = 2;
          minScore = 0.65;
          modelName = "buffalo_l";
        };
        url = "http://${ipImmichMachineLearning}:3003";
      };
      map = {
        enabled = true;
        darkStyle = "";
        lightStyle = "";
      };
      newVersionCheck.enabled = true;
      oauth = rec {
        enabled = true;
        autoLaunch = false;
        autoRegister = true;
        buttonText = "Login with Kanidm";

        mobileOverrideEnabled = true;
        mobileRedirectUri = "https://${immichDomain}/api/oauth/mobile-redirect";

        clientId = "immich";
        # clientSecret will be dynamically added in activation script
        issuerUrl = "https://${globals.services.kanidm.domain}/oauth2/openid/${clientId}";
        scope = "openid email profile";
        storageLabelClaim = "preferred_username";
      };
      passwordLogin.enabled = true;
      reverseGeocoding.enabled = true;
      server = {
        externalDomain = "https://${immichDomain}";
        loginPageMessage = "Besser im Stuhl einschlafen als im Schlaf einstuhlen.";
      };
      storageTemplate = {
        enabled = true;
        hashVerificationEnabled = true;
        template = "{{y}}/{{MM}}/{{filename}}";
      };
      theme.customCss = "";
      trash = {
        days = 30;
        enabled = true;
      };
    }
  );

  processedConfigFile = "/run/agenix/immich.config.json";

  version = "v1.117.0";
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
    IMMICH_CONFIG_FILE = "/immich.config.json";
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
  microvm.mem = 1024 * 12;
  microvm.vcpu = 16;

  # Forwarding required to masquerade podman network
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  environment.persistence."/state".directories = [
    {
      directory = "/var/lib/containers";
      mode = "0755";
    }
  ];

  # Mirror the original oauth2 secret
  age.secrets.immich-oauth2-client-secret = {
    inherit (nodes.ward-kanidm.config.age.secrets.kanidm-oauth2-immich) rekeyFile;
    mode = "440";
    group = "root";
  };

  system.activationScripts.agenixRooterDerivedSecrets = {
    # Run after agenix has generated secrets
    deps = ["agenix"];
    text = ''
      immichClientSecret=$(< ${config.age.secrets.immich-oauth2-client-secret.path})
      ${pkgs.jq}/bin/jq --arg immichClientSecret "$immichClientSecret" '.oauth.clientSecret = $immichClientSecret' ${configFile} > ${processedConfigFile}
      chmod 444 ${processedConfigFile}
    '';
  };

  wireguard.proxy-sentinel = {
    client.via = "sentinel";
    firewallRuleForNode.sentinel.allowedTCPPorts = [2283];
  };
  wireguard.proxy-home = {
    client.via = "ward";
    firewallRuleForNode.ward-web-proxy.allowedTCPPorts = [2283];
  };
  networking.nftables.chains.forward.into-immich-container = {
    after = ["conntrack"];
    rules = [
      "iifname proxy-sentinel ip saddr ${sentinelCfg.wireguard.proxy-sentinel.ipv4} tcp dport 3001 accept"
      "iifname proxy-home ip saddr ${wardWebProxyCfg.wireguard.proxy-home.ipv4} tcp dport 3001 accept"
      "iifname podman1 oifname lan accept"
    ];
  };

  globals.services.immich.domain = immichDomain;
  globals.monitoring.http.immich = {
    url = "https://${immichDomain}";
    expectedBodyRegex = "immutable.entry.app";
    network = "internet";
  };

  nodes.sentinel = {
    services.nginx = {
      upstreams.immich = {
        servers."${config.wireguard.proxy-sentinel.ipv4}:2283" = {};
        extraConfig = ''
          zone immich 64k;
          keepalive 2;
        '';
        monitoring = {
          enable = true;
          expectedBodyRegex = "immutable.entry.app";
        };
      };
      virtualHosts.${immichDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        locations."/" = {
          proxyPass = "http://immich";
          proxyWebsockets = true;
        };
        extraConfig = ''
          client_max_body_size 10G;
        '';
      };
    };
  };

  nodes.ward-web-proxy = {
    services.nginx = {
      upstreams.immich = {
        servers."${config.wireguard.proxy-home.ipv4}:2283" = {};
        extraConfig = ''
          zone immich 64k;
          keepalive 2;
        '';
        monitoring = {
          enable = true;
          expectedBodyRegex = "immutable.entry.app";
        };
      };
      virtualHosts.${immichDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        locations."/" = {
          proxyPass = "http://immich";
          proxyWebsockets = true;
        };
        extraConfig = ''
          client_max_body_size 10G;
          allow ${globals.net.home-lan.cidrv4};
          allow ${globals.net.home-lan.cidrv6};
          deny all;
        '';
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
  virtualisation.oci-containers.backend = "podman";
  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
    dockerCompat = true;
  };

  # Containers
  virtualisation.oci-containers.containers."immich_machine_learning" = {
    image = "ghcr.io/immich-app/immich-machine-learning:${version}";
    inherit environment;
    volumes = [
      "${processedConfigFile}:${environment.IMMICH_CONFIG_FILE}:ro"
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
  virtualisation.oci-containers.containers."immich_postgres" = {
    image = "tensorchord/pgvecto-rs:pg14-v0.2.0@sha256:90724186f0a3517cf6914295b5ab410db9ce23190a2d9d0b9dd6463e3fa298f0";
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
    image = "redis:6.2-alpine@sha256:51d6c56749a4243096327e3fb964a48ed92254357108449cb6e23999c37773c5";
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
      "${processedConfigFile}:${environment.IMMICH_CONFIG_FILE}:ro"
      "${config.age.secrets.postgres_password.path}:${config.age.secrets.postgres_password.path}:ro"
      "/etc/localtime:/etc/localtime:ro"
      "${upload_folder}:/usr/src/app/upload:rw"
    ];
    ports = [
      "2283:3001/tcp"
    ];
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
      podman network inspect immich-default || podman network create immich-default --opt isolate=true --subnet=10.89.0.0/24 --disable-dns
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
