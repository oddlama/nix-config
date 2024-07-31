{
  inputs,
  config,
  lib,
  ...
}: let
  inherit (config) globals;

  # Try to access the extra builtin we loaded via nix-plugins.
  # Throw an error if that doesn't exist.
  rageImportEncrypted = assert lib.assertMsg (builtins ? extraBuiltins.rageImportEncrypted) "The extra builtin 'rageImportEncrypted' is not available, so repo.secrets cannot be decrypted. Did you forget to add nix-plugins and point it to `./nix/extra-builtins.nix` ?";
    builtins.extraBuiltins.rageImportEncrypted;
in {
  imports = [
    (rageImportEncrypted inputs.self.secretsConfig.masterIdentities ./secrets/global.nix.age)
  ];

  globals = {
    net = {
      home-wan = {
        cidrv4 = "192.168.178.0/24";
        hosts.fritzbox.id = 1;
        hosts.ward.id = 2;
      };

      home-lan = {
        cidrv4 = "192.168.1.0/24";
        cidrv6 = "fd10::/64";
        hosts.ward.id = 1;
        hosts.sire.id = 2;
        hosts.ward-adguardhome.id = 3;
        hosts.ward-web-proxy.id = 4;
        hosts.sire-samba.id = 10;
        hosts.wallbox.id = 40;
        hosts.home-assistant-temp.id = 85;
      };

      proxy-home = {
        cidrv4 = "10.44.0.0/24";
        cidrv6 = "fd00:44::/120";
      };
    };

    monitoring = {
      dns = {
        cloudflare = {
          server = "1.1.1.1";
          domain = ".";
          network = "internet";
        };

        google = {
          server = "8.8.8.8";
          domain = ".";
          network = "internet";
        };
      };

      ping = {
        cloudflare = {
          hostv4 = "1.1.1.1";
          hostv6 = "2606:4700:4700::1111";
          network = "internet";
        };

        google = {
          hostv4 = "8.8.8.8";
          hostv6 = "2001:4860:4860::8888";
          network = "internet";
        };

        fritz-box = {
          hostv4 = globals.net.home-wan.hosts.fritzbox.ipv4;
          network = "home-wan";
        };
      };
    };
  };
}
