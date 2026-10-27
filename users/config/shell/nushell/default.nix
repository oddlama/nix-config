{
  lib,
  minimal,
  ...
}:
lib.optionalAttrs (!minimal) {
  programs.nushell = {
    enable = true;
    loadSessionVariables = false; # Preserve the pre-update environment setup.
    configFile.source = ./config.nu;
    envFile.source = ./env.nu;
  };

  home.persistence."/persist".directories = [
    ".config/nushell"
  ];
}
