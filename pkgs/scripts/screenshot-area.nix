{
  writeShellApplication,
  libnotify,
  xclip,
  tesseract,
  maim,
}:
writeShellApplication {
  name = "screenshot-area";
  text = ''
    set -euo pipefail
    umask 077

    date=$(date +"%Y-%m-%dT%H:%M:%S%:z")
    out="''${XDG_PICTURES_DIR-$HOME/Pictures}/screenshots/$date-selection.png"
    mkdir -p "$(dirname "$out")"

    ${maim}/bin/maim --color=.4,.7,1,0.2 --bordersize=1.0 --nodecorations=1 \
      --hidecursor --format=png --quality=10 --noopengl --select "$out"
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
