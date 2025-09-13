{ inputs, ... }:
{
  perSystem =
    {
      pkgs,
      system,
      ...
    }:
    {
      # For each major system, we provide a customized installer image that
      # has ssh and some other convenience stuff preconfigured.
      # Not strictly necessary for new setups.
      packages.live-iso = inputs.nixos-generators.nixosGenerate {
        inherit pkgs;
        modules = [
          ./installer-configuration.nix
          ../config/ssh.nix
        ];
        format =
          {
            x86_64-linux = "install-iso";
            aarch64-linux = "sd-aarch64-installer";
          }
          .${system};
      };
    };
}
