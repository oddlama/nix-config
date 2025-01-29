{
  config,
  pkgs,
  ...
}:
{
  age.secrets.influxdb-admin-password = {
    generator.script = "alnum";
    mode = "440";
    group = "influxdb2";
  };

  age.secrets.influxdb-admin-token = {
    generator.script = "alnum";
    mode = "440";
    group = "influxdb2";
  };

  age.secrets.hass-influxdb-token = {
    generator.script = "alnum";
    mode = "440";
    group = "influxdb2";
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/influxdb2";
      user = "influxdb2";
      group = "influxdb2";
      mode = "0700";
    }
  ];

  environment.systemPackages = [ pkgs.influxdb2-cli ];

  services.influxdb2 = {
    enable = true;
    settings = {
      reporting-disabled = true;
      http-bind-address = "127.0.0.1:8086";
    };
    provision = {
      enable = true;
      initialSetup = {
        organization = "default";
        bucket = "default";
        passwordFile = config.age.secrets.influxdb-admin-password.path;
        tokenFile = config.age.secrets.influxdb-admin-token.path;
      };
      organizations.home = {
        buckets.hass = { };
        auths.home-assistant = {
          readBuckets = [ "hass" ];
          writeBuckets = [ "hass" ];
          tokenFile = config.age.secrets.hass-influxdb-token.path;
        };
      };
    };
  };

  systemd.services.influxdb2.serviceConfig.RestartSec = "60"; # Retry every minute
}
