{pkgs, ...}: {
  home.file.".ssh/yubikey.pub".text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5Uq+CDy5Pmt3If5M6d8K/Q7HArU6sZ7sgoj3T521Wm cardno:15 209 174";
  programs.ssh = {
    enable = true;
    matchBlocks = let
      withYubikey = {identityFile = ["~/.ssh/yubikey.pub"];};
    in {
      "*" = {
        identitiesOnly = true;
      };
      meister =
        {
          user = "root";
          hostname = "meister.oddlama.org";
        }
        // withYubikey;
      envoy =
        {
          user = "root";
          hostname = "94.130.104.236";
        }
        // withYubikey;
      vm-base =
        {
          user = "root";
          proxyJump = "meister";
          hostname = "172.16.0.01";
        }
        // withYubikey;
      vm-misc =
        {
          user = "root";
          proxyJump = "meister";
          hostname = "172.16.0.16";
        }
        // withYubikey;
      vm-samba =
        {
          user = "root";
          proxyJump = "meister";
          hostname = "172.16.0.64";
        }
        // withYubikey;
      vm-nginx =
        {
          user = "root";
          proxyJump = "meister";
          hostname = "172.16.0.128";
        }
        // withYubikey;
      vm-radicale =
        {
          user = "root";
          proxyJump = "meister";
          hostname = "172.16.0.129";
        }
        // withYubikey;
      vm-vaultwarden =
        {
          user = "root";
          proxyJump = "meister";
          hostname = "172.16.0.130";
        }
        // withYubikey;
      vm-test =
        {
          user = "root";
          proxyJump = "meister";
          hostname = "172.16.0.255";
        }
        // withYubikey;
    };
  };
}
