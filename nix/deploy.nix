{
  self,
  deploy-rs,
  nixpkgs,
  ...
}: let
  inherit (nixpkgs) lib;

  generateNode = hostName: nixosCfg: let
    host = self.hosts.${hostName};
    inherit (deploy-rs.lib.${host.hostPlatform}) activate;
  in {
    remoteBuild = host.remoteBuild or true;
    hostname = host.address or hostName;
    profiles.system.path = activate.nixos nixosCfg;
  };
in {
  autoRollback = false;
  magicRollback = false;
  sshUser = "root";
  user = "root";
  sudo = "runuser -u";
  nodes = lib.mapAttrs generateNode (self.nixosConfigurations or {});
}
