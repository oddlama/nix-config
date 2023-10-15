{
  writeShellApplication,
  libnotify,
  xclip,
  maim,
  zbar,
  yq,
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
    out="''${XDG_PICTURES_DIR-$HOME/Pictures}/screenshots/$date-selection.png"
    mkdir -p "$(dirname "$out")"

    if ${maim}/bin/maim --color=.4,.7,1 --bordersize=1.0 --nodecorations=1 --hidecursor --format=png --quality=10 --noopengl --select \
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
        --hint="string:image-path:$out" \
        --hint="string:wired-tag:screenshot-$date" \
        || true
    else
      case "$?" in
        "4")
          ${libnotify}/bin/notify-send \
            "🔍 QR Code scan" "❌ 0 codes detected" \
            --hint="string:image-path:$out" \
            --hint="string:wired-tag:screenshot-$date" \
            || true
          ;;
        *)
          ${libnotify}/bin/notify-send \
            "🔍 QR Code scan" "❌ Error while processing image: zbarimg exited with code $?" \
            --hint="string:image-path:$out" \
            --hint="string:wired-tag:screenshot-$date" \
            || true
          ;;
      esac
    fi
  '';
}
