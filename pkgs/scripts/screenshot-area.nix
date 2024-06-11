{
  writeShellApplication,
  grimblast,
  libnotify,
  tesseract,
  wl-clipboard,
}:
writeShellApplication {
  name = "screenshot-area";
  runtimeInputs = [
    grimblast
    libnotify
    tesseract
    wl-clipboard
  ];
  text = ''
    umask 077

    date=$(date +"%Y-%m-%dT%H:%M:%S%:z")
    out="''${XDG_PICTURES_DIR-$HOME/Pictures}/screenshots/$date-selection.png"
    mkdir -p "$(dirname "$out")"

    grimblast --freeze save area "$out" || exit 2
    wl-copy -t image/png < "$out"

    declare -A NOTIFICATION_IDS
    function notify_wait_action() {
      id="$1"
      shift 1

      args=("--print-id")
      if [[ -v "NOTIFICATION_IDS[$id]" ]]; then
        args+=("--replace-id=''${NOTIFICATION_IDS[$id]}")
      fi
      args+=("$@")

      readarray -t __notify_output < <(notify-send "''${args[@]}" || true)
      NOTIFICATION_IDS["$id"]="''${__notify_output[0]-}"
      echo "''${__notify_output[1]-}"
    }

    function notify_nowait() {
      id="$1"
      shift 1

      args=("--print-id")
      if [[ -v "NOTIFICATION_IDS[$id]" ]]; then
        args+=("--replace-id=''${NOTIFICATION_IDS[$id]}")
      fi
      args+=("$@")

      readarray -t __notify_output < <(notify-send "''${args[@]}" || true)
      NOTIFICATION_IDS["$id"]="''${__notify_output[0]-}"
      unset __notify_output
    }

    title="📷 Screenshot captured"
    body="📋 image copied to clipboard"
    while true; do
      action=$(notify_wait_action main "$title" "$body" \
        --action=ocr="Run OCR" \
        --action=copy="Copy Image")

      case "$action" in
        ocr)
          notify_nowait main "$title" "⏳ Running OCR ..."

          if tesseract "$out" - -l eng+deu | wl-copy; then
            body="🔠 OCR copied to clipboard"
          else
            body="❌ Error while running OCR"
          fi
          ;;

        copy)
          wl-copy -t image/png < "$out"
          body="📋 image copied to clipboard"
          ;;

        *) exit 0 ;;
      esac
    done
  '';
}
