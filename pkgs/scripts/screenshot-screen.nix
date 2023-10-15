{
  writeShellApplication,
  libnotify,
  maim,
}:
writeShellApplication {
  name = "screenshot-screen";
  text = ''
    set -euo pipefail
    umask 077

    out="''${XDG_PICTURES_DIR-$HOME/Pictures}/screenshots/$(date +"%Y-%m-%dT%H:%M:%S%:z")-fullscreen.png"
    mkdir -p "$(dirname "$out")"

    ${maim}/bin/maim --hidecursor --format=png --quality=10 --noopengl "$out"
    ${libnotify}/bin/notify-send \
      "📷 Screenshot captured" "💾 Saved to $out" \
      || true
  '';
}
