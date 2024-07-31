{inputs, ...}: {
  perSystem = {
    config,
    pkgs,
    ...
  }: {
    apps.setupHetznerStorageBoxes = import (inputs.nixos-extra-modules + "/apps/setup-hetzner-storage-boxes.nix") {
      inherit pkgs;
      nixosConfigurations = inputs.self.nodes;
      decryptIdentity = builtins.head config.secretsConfig.masterIdentities;
    };
  };
}
