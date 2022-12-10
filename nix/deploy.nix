{
  self,
  deploy-rs,
  nixpkgs,
  ...
}: let
  inherit (nixpkgs) lib;
  hosts = (import ./hosts.nix).all;

  genNode = hostName: nixosCfg: let
    inherit (hosts.${hostName}) hostname hostPlatform remoteBuild;
    inherit (deploy-rs.lib.${hostPlatform}) activate;
  in {
    inherit remoteBuild hostname;
    profiles.system.path = activate.nixos nixosCfg;
  };
in {
  autoRollback = false;
  magicRollback = false;
  sshUser = "root";
  user = "root";
  sudo = "runuser -u";
  nodes = lib.mapAttrs genNode self.nixosConfigurations;
}
