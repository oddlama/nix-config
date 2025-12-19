{
  inputs,
  ...
}:
{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  programs.noctalia-shell = {
    enable = true;
    systemd.enable = true;

    settings = {
      bar = {
        density = "default";
        position = "bottom";
        backgroundOpacity = 0;
        showCapsule = true;
        floating = true;
      };
    };
  };
}
