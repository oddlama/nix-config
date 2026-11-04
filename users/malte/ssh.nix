{ config, lib, ... }:
let
  # The host entries in userSecrets still use the old matchBlocks attribute names
  toDirectives =
    block:
    lib.filterAttrs (_: v: v != null) {
      HostName = block.hostname or null;
      Port = block.port or null;
      User = block.user or null;
    };
in
{
  home.file.".ssh/yubikey.pub".text =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5Uq+CDy5Pmt3If5M6d8K/Q7HArU6sZ7sgoj3T521Wm";
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        User = "root";
        ForwardAgent = false;
        AddKeysToAgent = "no";
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
        ControlMaster = "auto";
        IdentitiesOnly = true;
        IdentityFile = [ "~/.ssh/yubikey.pub" ];
      };
    }
    // lib.mapAttrs (_: toDirectives) config.userSecrets.ssh.matchBlocks;
  };
}
