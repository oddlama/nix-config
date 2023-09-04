{
  home.file.".ssh/yubikey.pub".text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5Uq+CDy5Pmt3If5M6d8K/Q7HArU6sZ7sgoj3T521Wm";
  programs.ssh = {
    enable = true;
    matchBlocks = {
      "*" = {
        identityFile = ["~/.ssh/yubikey.pub"];
        identitiesOnly = true;
      };
      # TODO more from secrets nixosConfiguration.repo.secrets.global
      meister = {
        user = "root";
        hostname = "meister.oddlama.org";
      };
      envoy = {
        user = "root";
        hostname = "94.130.104.236";
      };
      vm-base = {
        user = "root";
        proxyJump = "meister";
        hostname = "172.16.0.01";
      };
    };
  };
}
