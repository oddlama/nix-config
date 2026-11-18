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
  # Resident FIDO2 key (ssh:personal), served by skagent
  home.file.".ssh/yubikey-sk.pub".text =
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAICB1r4qkbAwGGo/LEiEXlzFeAVr3NDUyFFLLHF9X5uhaAAAADHNzaDpwZXJzb25hbA== yubikey:12764721";
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
        # The sk key first, since SSH_AUTH_SOCK points at skagent by default
        IdentityFile = [
          "~/.ssh/yubikey-sk.pub"
          "~/.ssh/yubikey.pub"
        ];
      };
      # Secondary GitHub account: clone with git@github3:<owner>/<repo>.git
      # IdentityFile accumulates with the yubikey from "*", and ssh always offers
      # agent-held keys first, so GitHub would accept the yubikey (main account).
      # Disabling the agent here leaves the yubikey unusable and this key wins.
      "github3" = {
        HostName = "github.com";
        User = "git";
        IdentityFile = [ "~/.ssh/id_ed25519" ];
        IdentityAgent = "none";
      };
    }
    // lib.mapAttrs (_: toDirectives) config.userSecrets.ssh.matchBlocks;
  };
}
