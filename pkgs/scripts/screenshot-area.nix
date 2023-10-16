{
  lib,
  writeShellApplication,
  flameshot,
  libnotify,
  moreutils,
  tesseract,
  xclip,
}:
writeShellApplication {
  name = "screenshot-area";
  text = ''
    set -euo pipefail
    umask 077

    date=$(date +"%Y-%m-%dT%H:%M:%S%:z")
    out="''${XDG_PICTURES_DIR-$HOME/Pictures}/screenshots/$date-selection.png"
    mkdir -p "$(dirname "$out")"

    # Always use native scaling to ensure flameshot is fullscreen across monitors
    export QT_AUTO_SCREEN_SCALE_FACTOR=0
    export QT_SCREEN_SCALE_FACTORS=""

    # Use sponge to create the file on success only
    if ${lib.getExe flameshot} gui --raw 2>&1 1> >(${moreutils}/bin/sponge "$out") | grep -q "flameshot: info:.*aborted."; then
      exit 1
    fi

    ${xclip}/bin/xclip -selection clipboard -t image/png < "$out"
    action=$(${libnotify}/bin/notify-send \
      "📷 Screenshot captured" "📋 copied to clipboard" \
      --hint="string:wired-tag:screenshot-$date" \
      --action=ocr=OCR) \
      || true

    if [[ "$action" == "ocr" ]]; then
      ${libnotify}/bin/notify-send \
        "📷 Screenshot captured" "⏳ Running OCR ..." \
        --hint="string:wired-tag:screenshot-$date" \
        || true

      if ${tesseract}/bin/tesseract "$out" - -l eng+deu | ${xclip}/bin/xclip -selection clipboard; then
        ${libnotify}/bin/notify-send \
          "📷 Screenshot captured" "🔠 OCR copied to clipboard" \
          --hint="string:wired-tag:screenshot-$date" \
          || true
      else
        ${libnotify}/bin/notify-send \
          "📷 Screenshot captured" "❌ Error while running OCR" \
          --hint="string:wired-tag:screenshot-$date" \
          || true
      fi
    fi
  '';
}
