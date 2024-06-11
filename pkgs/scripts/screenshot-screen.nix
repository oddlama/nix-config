{
  writeShellApplication,
  grimblast,
  libnotify,
}:
writeShellApplication {
  name = "screenshot-screen";
  runtimeInputs = [
    grimblast
    libnotify
  ];
  text = ''
    umask 077

    date=$(date +"%Y-%m-%dT%H:%M:%S%:z")
    out="''${XDG_PICTURES_DIR-$HOME/Pictures}/screenshots/$date-fullscreen.png"
    mkdir -p "$(dirname "$out")"

    grimblast --freeze save screen "$out" || exit 2
    notify-send \
      "📷 Screenshot captured" "💾 Saved to $out" \
      --hint="string:wired-tag:screenshot-$date" \
      || true
  '';
}
