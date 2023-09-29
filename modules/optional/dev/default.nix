{
  inputs,
  pkgs,
  lib,
  minimal,
  ...
}:
lib.optionalAttrs (!minimal) {
  imports = [
    inputs.nixseparatedebuginfod.nixosModules.default
    ./documentation.nix
    ./yubikey.nix
  ];

  environment.systemPackages = [pkgs.man-pages pkgs.man-pages-posix];
  environment.enableDebugInfo = true;

  # Add the agenix-rekey sandbox path permanently to avoid adding myself to trusted-users
  nix.settings.extra-sandbox-paths = ["/var/tmp/agenix-rekey"];

  services.nixseparatedebuginfod.enable = true;
  # We need a system-level user to be able to use nix.settings.allowed-users with it.
  # TODO: remove once https://github.com/NixOS/nix/issues/9071 is fixed
  systemd.services.nixseparatedebuginfod.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "nixseparatedebuginfod";
    Group = "nixseparatedebuginfod";
    PrivateTmp = true;
  };
  users = {
    groups.nixseparatedebuginfod = {};
    users.nixseparatedebuginfod = {
      description = "nixseparatedebuginfod user";
      group = "nixseparatedebuginfod";
    };
  };
  nix.settings.allowed-users = ["nixseparatedebuginfod"];
}
