{
  config,
  inputs,
  lib,
  nixos-hardware,
  nodeSecrets,
  pkgs,
  ...
}: {
  imports = [
    nixos-hardware.common-cpu-intel
    nixos-hardware.common-pc-ssd

    ../common/core
    ../common/hardware/intel.nix
    ../common/hardware/physical.nix
    ../common/initrd-ssh.nix
    ../common/efi.nix
    ../common/zfs.nix

    ../../users/root

    ./fs.nix
    ./net.nix
  ];

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" "sdhci_pci" "r8169"];

  extra.microvms = let
    macOffset = config.lib.net.mac.addPrivate nodeSecrets.networking.interfaces.lan.mac;
  in {
    test = {
      autostart = true;
      mac = macOffset "00:00:00:00:00:11";
      macvtap = "lan";
      system = "x86_64-linux";
    };
  };

  #services.authelia.instances.main = {
  #  enable = true;
  #  settings = {
  #    theme = "dark";
  #    log = {
  #      level = "info";
  #      format = "text";
  #    };
  #    server = {
  #      host = "127.0.0.1";
  #      port = 9091;
  #    };
  #    session = {
  #      name = "session";
  #      domain = "pas.sh";
  #    };
  #    authentication_backend.ldap = {
  #      implementation = "custom";
  #      url = "ldap://127.0.0.1:3890";
  #      base_dn = "dc=pas,dc=sh";
  #      username_attribute = "uid";
  #      additional_users_dn = "ou=people";
  #      users_filter = "(&({username_attribute}={input})(objectclass=person))";
  #      additional_groups_dn = "ou=groups";
  #      groups_filter = "(member={dn})";
  #      group_name_attribute = "cn";
  #      mail_attribute = "mail";
  #      display_name_attribute = "uid";
  #      user = "uid=authelia,ou=people,dc=pas,dc=sh";
  #    };
  #    storage.local = {
  #      path = "/var/lib/authelia-${cfg.name}/db.sqlite3";
  #    };
  #    access_control = {
  #      default_policy = "deny";
  #    };
  #    notifier.smtp = rec {
  #      host = "smtp.fastmail.com";
  #      port = 587;
  #      username = "a@example.com";
  #      sender = "noreply@example.com";
  #      startup_check_address = sender;
  #      disable_html_emails = true;
  #    };
  #    identity_providers.oidc = {
  #      cors.allowed_origins_from_client_redirect_uris = true;
  #      cors.endpoints = [
  #        "authorization"
  #          "introspection"
  #          "revocation"
  #          "token"
  #          "userinfo"
  #      ];
  #    };
  #  };
  #};

  #microvm.vms.agag = {
  #  flake = self;
  #  updateFlake = microvm;
  #};
  #microvm.autostart = ["guest"];
}
