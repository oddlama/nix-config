{
  config,
  lib,
  nixosConfig,
  pkgs,
  ...
}: let
  rageWrapper = pkgs.writeShellScript "rage-decrypt-yubikey" ''
    export PATH="${pkgs.age-plugin-yubikey}:$PATH"
    exec ${pkgs.rage}/bin/rage
  '';
in {
  accounts.email.accounts =
    lib.flip lib.mapAttrs' config.userSecrets.accounts.email
    (n: v:
      lib.nameValuePair v.address ({
          # TODO genericize
          passwordCommand =
            [rageWrapper.out "-d"]
            ++ lib.concatMap (x: ["-i" x]) nixosConfig.age.rekey.masterIdentities
            ++ [nixosConfig.age.secrets.mailpw-206fd3b8.path];

          thunderbird = {
            enable = true;
            profiles = ["personal"];
          };
        }
        // v));

  # TODO dont send html setting

  programs.thunderbird = {
    enable = true;

    profiles.personal = {
      isDefault = true;
      withExternalGnupg = true;
    };
  };

  home.persistence."/state".directories = [
    ".cache/thunderbird"
  ];

  home.persistence."/persist".directories = [
    ".thunderbird"
  ];

  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/mailto" = ["thunderbird.desktop"];
    "message/rfc822" = ["thunderbird.desktop"];
  };
}
