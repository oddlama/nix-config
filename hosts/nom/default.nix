{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-intel
    inputs.nixos-hardware.nixosModules.common-pc-laptop
    inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
    ../../modules/optional/hardware/intel.nix
    ../../modules/optional/hardware/physical.nix

    ../../modules
    ../../modules/optional/boot-efi.nix
    ../../modules/optional/initrd-ssh.nix
    ../../modules/optional/dev
    ../../modules/optional/graphical
    ../../modules/optional/laptop.nix
    #../../modules/optional/sound.nix
    ../../modules/optional/zfs.nix

    ../../users/myuser

    ./fs.nix
    ./net.nix
  ];

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod"];

  console = {
    font = "ter-v28n";
    packages = [pkgs.terminus_font];
  };

  services.influxdb2 = {
    enable = true;
    settings = {
      reporting-disabled = true;
      http-bind-address = "localhost:8086";
    };
    initialSetup = {
      enable = true;
      organization = "servers";
      bucket = "telegraf";

      passwordFile = pkgs.writeText "tmp-pw" "ExAmPl3PA55W0rD";
      tokenFile = pkgs.writeText "tmp-tok" "asroiuhoiuahnawo4unhasdorviuhngoiuhraoug";
    };
    deleteOrganizations = ["delorg"];
    deleteBuckets = [
      {
        name = "delbucket";
        org = "delorg";
      }
    ];
    deleteUsers = ["deluser"];
    deleteRemotes = [
      {
        name = "delremote";
        org = "delorg";
      }
    ];
    deleteReplications = [
      {
        name = "delreplication";
        org = "delorg";
      }
    ];
    deleteApiTokens = [
      {
        name = "deltoken";
        org = "delorg";
        user = "deluser";
      }
    ];
    ensureOrganizations = [
      {
        name = "myorg";
        description = "Myorg description";
      }
      #{
      #  name = "delorg";
      #}
    ];
    ensureBuckets = [
      {
        name = "mybucket";
        org = "myorg";
        description = "Mybucket description";
      }
      #{
      #  name = "delbucket";
      #  org = "delorg";
      #}
    ];
    ensureUsers = [
      {
        name = "myuser";
        org = "myorg";
        passwordFile = pkgs.writeText "tmp-pw" "abcgoiuhaoga";
      }
      #{
      #  name = "deluser";
      #  org = "delorg";
      #  passwordFile = pkgs.writeText "tmp-pw" "abcgoiuhaoga";
      #}
    ];
    #ensureRemotes = [
    #  {
    #    name = "delremote";
    #    org = "delorg";
    #    remoteUrl = "http://localhost:8087";
    #    remoteOrgId = "a1b2c3d4a1b2c3d4";
    #    remoteTokenFile = pkgs.writeText "tmp-pw" "abcgoiuhaoga";
    #  }
    #];
    #ensureReplications = [
    #  {
    #    name = "delreplication";
    #    org = "delorg";
    #    remote = "delremote";
    #    localBucket = "delbucket";
    #    remoteBucket = "delbucket2";
    #  }
    #];
    ensureApiTokens = [
      {
        name = "mytoken";
        org = "myorg";
        user = "myuser";
        readBuckets = ["mybucket"];
        writeBuckets = ["mybucket"];
      }
      #{
      #  name = "deltoken";
      #  org = "delorg";
      #  user = "deluser";
      #  readBuckets = ["delbucket"];
      #  writeBuckets = ["delbucket"];
      #}
    ];
  };
}
