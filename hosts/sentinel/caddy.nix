{
  config,
  lib,
  nodes,
  nodeName,
  pkgs,
  ...
}: {
  users.groups.acme.members = ["caddy"];

  # TODO assertions = lib.flip lib.mapAttrsToList config.users.users
  # TODO   (name: user: {
  # TODO     assertion = user.uid != null;
  # TODO     message = "non-deterministic uid detected for: ${name}";
  # TODO   });

  services.caddy = {
    enable = true;
    package = pkgs.caddy.withPackages {
      plugins = [
        {
          name = "github.com/greenpau/caddy-security";
          version = "v1.1.18";
        }
      ];
      vendorHash = "sha256-RqSXQihtY5+ACaMo7bLdhu1A+qcraexb1W/Ia+aUF1k";
    };
  };
}
