{
  lib,
  writeShellApplication,
  flameshot,
  libnotify,
  xclip,
  yq,
  zbar,
}:
writeShellApplication {
  name = "screenshot-area-scan-qr";
  text = ''
    set -euo pipefail
    umask 077

    # Create in-memory tmpfile
    TMPFILE=$(mktemp)
    exec 3<>"$TMPFILE"
    rm "$TMPFILE" # still open in-memory as /dev/fd/3
    TMPFILE=/dev/fd/3

    date=$(date +"%Y-%m-%dT%H:%M:%S%:z")

    # Always use native scaling to ensure flameshot is fullscreen across monitors
    export QT_AUTO_SCREEN_SCALE_FACTOR=0
    export QT_SCREEN_SCALE_FACTORS=""

    if ${lib.getExe flameshot} gui --raw \
      | ${zbar}/bin/zbarimg --xml - > "$TMPFILE"; then
      N=$(${yq}/bin/xq -r '.barcodes.source.index.symbol | if type == "array" then length else 1 end' < "$TMPFILE")
      # Append codes Copy data separated by ---
      DATA=$(${yq}/bin/xq -r '.barcodes.source.index.symbol | if type == "array" then .[0].data else .data end' < "$TMPFILE")
      for ((i=1;i<N;++i)); do
        DATA="$DATA"$'\n'"---"$'\n'"$(${yq}/bin/xq -r ".barcodes.source.index.symbol[$i].data" < "$TMPFILE")"
      done
      ${xclip}/bin/xclip -selection clipboard <<< "$DATA"
      ${libnotify}/bin/notify-send \
        "🔍 QR Code scan" "✅ $N codes detected\n📋 copied ''${#DATA} bytes" \
        --hint="string:image-path:"${./assets/qr-scan.png} \
        --hint="string:wired-tag:screenshot-$date" \
        || true
    else
      case "$?" in
        "4")
          ${libnotify}/bin/notify-send \
            "🔍 QR Code scan" "❌ 0 codes detected" \
            --hint="string:image-path:"${./assets/qr-scan.png} \
            --hint="string:wired-tag:screenshot-$date" \
            || true
          ;;
        *)
          ${libnotify}/bin/notify-send \
            "🔍 QR Code scan" "❌ Error while processing image: zbarimg exited with code $?" \
            --hint="string:image-path:"${./assets/qr-scan.png} \
            --hint="string:wired-tag:screenshot-$date" \
            || true
          ;;
      esac
    fi
  '';
}
