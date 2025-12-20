{
  writeShellApplication,
  grimblast,
  libnotify,
  satty,
  tesseract,
  wl-clipboard-rs,
}:
writeShellApplication {
  name = "screenshot-area";
  runtimeInputs = [
    grimblast
    libnotify
    satty
    tesseract
    wl-clipboard-rs
  ];
  text = ''
    umask 077

    date=$(date +"%Y-%m-%dT%H:%M:%S%:z")
    out_base="''${XDG_PICTURES_DIR-$HOME/Pictures}/screenshots/$date-selection"
    out="$out_base.png"
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

    edit_counter=1
    title="📷 Screenshot captured"
    body="📋 image copied to clipboard"
    while true; do
      action=$(notify_wait_action main "$title" "$body" \
        --action=ocr="🔠 Run OCR" \
        --action=edit="✏️ Edit" \
        --action=copy="📋 Copy Image")

      case "$action" in
        ocr)
          notify_nowait main "$title" "⏳ Running OCR ..."

          if tesseract "$out" - -l eng+deu | wl-copy; then
            body="🔠 OCR copied to clipboard"
          else
            body="❌ Error while running OCR"
          fi
          ;;

        edit)
          satty --filename "$out" \
            --output-filename "$out_base-edit-$edit_counter.png" \
            --copy-command wl-copy \
            --initial-tool brush \
            --save-after-copy \
            --fullscreen \
            --early-exit
          body="🎨 image edited"
          edit_counter=$((edit_counter + 1))
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
