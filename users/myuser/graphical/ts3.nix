{pkgs, ...}: let
  ts3 = pkgs.writeShellApplication {
    name = "teamspeak3";
    runtimeInputs = [
      pkgs.teamspeak_client
    ];
    text = ''
      export TS3_CONFIG_DIR=".config/teamspeak3"
      exec ts3client
    '';
  };
in {
  home.packages = [ts3];
  home.persistence."/persist".directories = [
    ".config/teamspeak3"
  ];
}
