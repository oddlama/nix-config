{config, ...}: {
  home.file.".ssh/yubikey.pub".text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5Uq+CDy5Pmt3If5M6d8K/Q7HArU6sZ7sgoj3T521Wm";
  programs.ssh = {
    enable = true;
    controlMaster = "auto";
    inherit (config.userSecrets.ssh) matchBlocks;
  };
}
