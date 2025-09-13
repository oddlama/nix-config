{
  config,
  globals,
  lib,
  nodes,
  ...
}:
let
  immichDomain = "immich.${globals.domains.me}";
in
{
  microvm.mem = 1024 * 12;
  microvm.vcpu = 16;

  # Mirror the original oauth2 secret
  age.secrets.immich-oauth2-client-secret = {
    inherit (nodes.ward-kanidm.config.age.secrets.kanidm-oauth2-immich) rekeyFile;
    mode = "440";
    group = "immich";
  };

  wireguard.proxy-sentinel = {
    client.via = "sentinel";
    firewallRuleForNode.sentinel.allowedTCPPorts = [ 2283 ];
  };
  wireguard.proxy-home = {
    client.via = "ward";
    firewallRuleForNode.ward-web-proxy.allowedTCPPorts = [ 2283 ];
  };

  globals.services.immich.domain = immichDomain;
  globals.monitoring.http.immich = {
    url = "https://${immichDomain}";
    expectedBodyRegex = "immutable.entry.app";
    network = "internet";
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/cache/immich";
      user = "immich";
      group = "immich";
      mode = "0750";
    }
  ];

  environment.persistence."/storage".directories = [
    {
      directory = "/var/lib/immich";
      user = "immich";
      group = "immich";
      mode = "0750";
    }
  ];

  services.immich = {
    enable = true;
    # We use VectorChord from the beginning
    database.enableVectors = false;
    environment = {
      IMMICH_LOG_LEVEL = "verbose";
      IMMICH_TRUSTED_PROXIES = lib.concatStringsSep "," [
      ];
    };
    settings = {
      backup.database = {
        cronExpression = "0 02 * * *";
        enabled = true;
        keepLastAmount = 14;
      };
      ffmpeg = {
        accel = "disabled";
        accelDecode = false;
        acceptedAudioCodecs = [
          "aac"
          "mp3"
          "libopus"
          "pcm_s16le"
        ];
        acceptedContainers = [
          "mov"
          "ogg"
          "webm"
        ];
        acceptedVideoCodecs = [ "h264" ];
        bframes = -1;
        cqMode = "auto";
        crf = 23;
        gopSize = 0;
        maxBitrate = "0";
        preferredHwDevice = "auto";
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
      image = {
        colorspace = "p3";
        extractEmbedded = false;
        preview = {
          format = "jpeg";
          quality = 80;
          size = 1440;
        };
        thumbnail = {
          format = "webp";
          quality = 80;
          size = 250;
        };
      };
      job = {
        backgroundTask.concurrency = 5;
        faceDetection.concurrency = 2;
        library.concurrency = 5;
        metadataExtraction.concurrency = 5;
        migration.concurrency = 5;
        notifications.concurrency = 5;
        search.concurrency = 5;
        sidecar.concurrency = 5;
        smartSearch.concurrency = 2;
        thumbnailGeneration.concurrency = 3;
        videoConversion.concurrency = 1;
      };
      library = {
        scan = {
          cronExpression = "0 0 * * *";
          enabled = true;
        };
        watch.enabled = false;
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
        duplicateDetection = {
          enabled = true;
          maxDistance = 0.01;
        };
        enabled = true;
        facialRecognition = {
          enabled = true;
          maxDistance = 0.5;
          minFaces = 2;
          minScore = 0.65;
          modelName = "buffalo_l";
        };
        urls = [ "http://localhost:3003" ];
      };
      map = {
        darkStyle = "https://tiles.immich.cloud/v1/style/dark.json";
        enabled = true;
        lightStyle = "https://tiles.immich.cloud/v1/style/light.json";
      };
      metadata.faces.import = false;
      newVersionCheck.enabled = true;
      notifications = {
        smtp = {
          enabled = false;
          from = "";
          replyTo = "";
          transport = {
            host = "";
            ignoreCert = false;
            password = "";
            port = 587;
            username = "";
          };
        };
      };
      oauth = rec {
        autoLaunch = false;
        autoRegister = true;
        buttonText = "Login with Kanidm";
        clientId = "immich";
        clientSecret._secret = config.age.secrets.immich-oauth2-client-secret.path;
        defaultStorageQuota = null;
        enabled = true;
        issuerUrl = "https://${globals.services.kanidm.domain}/oauth2/openid/${clientId}";
        mobileOverrideEnabled = true;
        mobileRedirectUri = "https://${immichDomain}/api/oauth/mobile-redirect";
        profileSigningAlgorithm = "none";
        scope = "openid email profile";
        signingAlgorithm = "ES256";
        storageLabelClaim = "preferred_username";
        storageQuotaClaim = "immich_quota";
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
        template = "{{y}}/{{y}}-{{MM}}-{{dd}}/{{filename}}";
      };
      theme.customCss = "";
      trash = {
        days = 30;
        enabled = true;
      };
      user.deleteDelay = 7;
    };
  };

  nodes.sentinel = {
    services.nginx = {
      upstreams.immich = {
        servers."${globals.wireguard.proxy-sentinel.hosts.${config.node.name}.ipv4}:2283" = { };
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
          client_max_body_size 50G;
          proxy_buffering off;
          proxy_request_buffering off;
          proxy_read_timeout 600s;
          proxy_send_timeout 600s;
          send_timeout       600s;
        '';
      };
    };
  };

  nodes.ward-web-proxy = {
    services.nginx = {
      upstreams.immich = {
        servers."${globals.wireguard.proxy-home.hosts.${config.node.name}.ipv4}:2283" = { };
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
          extraConfig = '''';
        };
        extraConfig = ''
          client_max_body_size 50G;
          proxy_buffering off;
          proxy_request_buffering off;
          proxy_read_timeout 600s;
          proxy_send_timeout 600s;
          send_timeout       600s;
          allow ${globals.net.home-lan.vlans.home.cidrv4};
          allow ${globals.net.home-lan.vlans.home.cidrv6};
          # Firezone traffic
          allow ${globals.net.home-lan.vlans.services.hosts.ward.ipv4};
          allow ${globals.net.home-lan.vlans.services.hosts.ward.ipv6};
          deny all;
        '';
      };
    };
  };
}
