{
  lib,
  writeShellApplication,
  flameshot,
  libnotify,
  moreutils,
}:
writeShellApplication {
  name = "screenshot-screen";
  text = ''
    set -euo pipefail
    umask 077

    date=$(date +"%Y-%m-%dT%H:%M:%S%:z")
    out="''${XDG_PICTURES_DIR-$HOME/Pictures}/screenshots/$date-fullscreen.png"
    mkdir -p "$(dirname "$out")"

    ${lib.getExe flameshot} full --raw | ${moreutils}/bin/sponge "$out"
    ${libnotify}/bin/notify-send \
      "📷 Screenshot captured" "💾 Saved to $out" \
      --hint="string:wired-tag:screenshot-$date" \
      || true
  '';
}
