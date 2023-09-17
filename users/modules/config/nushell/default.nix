{
  programs.nushell = {
    enable = true;
    configFile.source = ./config.nu;
    envFile.source = ./env.nu;
  };

  home.persistence."/persist".directories = [
    ".config/nushell"
  ];

  # XXX: remove once removed. DEBOALOGR
  programs.starship.enableNushellIntegration = false;
  programs.atuin.enableNushellIntegration = false;
}
