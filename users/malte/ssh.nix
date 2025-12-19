{ config, lib, ... }:
{
  home.file.".ssh/yubikey.pub".text =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5Uq+CDy5Pmt3If5M6d8K/Q7HArU6sZ7sgoj3T521Wm";
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = lib.recursiveUpdate {
      "*" = {
        forwardAgent = false;
        addKeysToAgent = "no";
        compression = false;
        serverAliveInterval = 0;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        userKnownHostsFile = "~/.ssh/known_hosts";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "no";
        controlMaster = "auto";
        identitiesOnly = true;
        identityFile = [ "~/.ssh/yubikey.pub" ];
      };
    } config.userSecrets.ssh.matchBlocks;
  };
}
