{
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    lutris
    wineWowPackages.stable
    winetricks
  ];

  home.persistence."/state".directories = [
    ".config/lutris"
    ".local/share/lutris"
    "Games"
  ];

  xdg.desktopEntries.LeagueOfLegends = {
    name = "League of Legends";
    icon = "league-of-legends";
    # XXX: TODO as popup dunst?
    exec = toString (pkgs.writeShellScript "league-launcher-script" ''
      set -euo pipefail
      if [[ "$(sysctl -n abi.vsyscall32)" != 0 ]]; then
        echo "Please disable abi.vsyscall32 as root to make the anti-cheat happy:"
        echo "  sysctl -w abi.vsyscall32=0"
        exit 1
      fi

      LUTRIS_SKIP_INIT=1 ${pkgs.lutris}/bin/lutris lutris:rungame/league-of-legends
    '');
    categories = ["Game"];
    type = "Application";
  };
}
