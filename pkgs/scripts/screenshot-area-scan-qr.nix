{
  writeShellApplication,
  grimblast,
  libnotify,
  tesseract,
  wl-clipboard-rs,
  yq,
  zbar,
}:
writeShellApplication {
  name = "screenshot-area-scan-qr";
  runtimeInputs = [
    grimblast
    libnotify
    tesseract
    wl-clipboard-rs
    yq
    zbar
  ];
  text = ''
    umask 077

    # Create in-memory tmpfile
    TMPFILE=$(mktemp)
    exec 3<>"$TMPFILE"
    rm "$TMPFILE" # still open in-memory as /dev/fd/3
    TMPFILE=/dev/fd/3

    if grimblast --freeze save area - \
      | zbarimg --xml - > "$TMPFILE"; then
      N=$(xq -r '.barcodes.source.index.symbol | if type == "array" then length else 1 end' < "$TMPFILE")
      # Append codes Copy data separated by ---
      DATA=$(xq -r '.barcodes.source.index.symbol | if type == "array" then .[0].data else .data end' < "$TMPFILE")
      for ((i=1;i<N;++i)); do
        DATA="$DATA"$'\n'"---"$'\n'"$(xq -r ".barcodes.source.index.symbol[$i].data" < "$TMPFILE")"
      done
      wl-copy <<< "$DATA"
      notify-send \
        "🔍 QR Code scan" "✅ $N codes detected\n📋 copied ''${#DATA} bytes" \
        --hint="string:image-path:"${./assets}/qr-scan.png \
        || true
    else
      case "$?" in
        "4")
          notify-send \
            "🔍 QR Code scan" "❌ 0 codes detected" \
            --hint="string:image-path:"${./assets}/qr-scan.png \
            || true
          ;;
        *)
          notify-send \
            "🔍 QR Code scan" "❌ Error while processing image: zbarimg exited with code $?" \
            --hint="string:image-path:"${./assets}/qr-scan.png \
            || true
          ;;
      esac
    fi
  '';
}
