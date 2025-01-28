{
  inputs,
  config,
  lib,
  nodes,
  ...
}:
let
  inherit (config) globals;

  # Try to access the extra builtin we loaded via nix-plugins.
  # Throw an error if that doesn't exist.
  rageImportEncrypted =
    assert lib.assertMsg (builtins ? extraBuiltins.rageImportEncrypted)
      "The extra builtin 'rageImportEncrypted' is not available, so repo.secrets cannot be decrypted. Did you forget to add nix-plugins and point it to `./nix/extra-builtins.nix` ?";
    builtins.extraBuiltins.rageImportEncrypted;
in
{
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
        vlans = {
          services = {
            id = 5;
            cidrv4 = "192.168.5.0/24";
            cidrv6 = "fd05::/64";
            hosts.ward.id = 1;
            hosts.sire.id = 2;
            hosts.ward-adguardhome = {
              id = 3;
              inherit (nodes.ward-adguardhome.config.lib.microvm.interfaces.vlan-services) mac;
            };
            hosts.ward-web-proxy = {
              id = 4;
              inherit (nodes.ward-web-proxy.config.lib.microvm.interfaces.vlan-services) mac;
            };
            hosts.sausebiene.id = 5;
            hosts.sire-samba = {
              id = 10;
              inherit (nodes.sire-samba.config.lib.microvm.interfaces.vlan-services) mac;
            };
          };
          home = {
            id = 10;
            cidrv4 = "192.168.10.0/24";
            cidrv6 = "fd10::/64";
            hosts.ward.id = 1;
            hosts.sire.id = 2;
            hosts.sausebiene.id = 5;
          };
          devices = {
            id = 20;
            cidrv4 = "192.168.20.0/24";
            cidrv6 = "fd20::/64";
            hosts.ward.id = 1;
            hosts.sire.id = 2;
            hosts.sausebiene.id = 5;
            hosts.scanner-ads-4300n = {
              id = 23;
              mac = globals.macs.scanner-ads-4300n;
            };
            hosts.epsondc44f7 = {
              id = 30;
              mac = globals.macs.epsondc44f7;
            };
            hosts.wallbox = {
              id = 40;
              mac = globals.macs.wallbox;
            };
          };
          iot = {
            id = 30;
            cidrv4 = "192.168.30.0/24";
            cidrv6 = "fd30::/64";
            hosts.ward.id = 1;
            hosts.sausebiene.id = 5;
            hosts.philips-ac2889 = {
              id = 21;
              mac = globals.macs.scanner-ads-4300n;
            };
            hosts.bambulab-p1s = {
              id = 22;
              mac = globals.macs.bambulab-p1s;
            };
          };
          guests = {
            id = 50;
            cidrv4 = "192.168.50.0/24";
            cidrv6 = "fd50::/64";
            hosts.ward.id = 1;
          };
        };
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
