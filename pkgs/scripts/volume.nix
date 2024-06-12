{
  writeShellApplication,
  bc,
  libnotify,
  wireplumber,
}:
writeShellApplication {
  name = "volume";
  text = ''
    set -euo pipefail

    ${wireplumber}/bin/wpctl "$1" "$2" "$3"
    current_volume=$(${wireplumber}/bin/wpctl get-volume "$2")
    case "''${2,,}" in
      *"source"*) type=source ;;
      *) type=sink ;;
    esac

    case "$3" in
      *"%+") image=${./assets}/audio-"$type"-increase.svg ;;
      *"%-") image=${./assets}/audio-"$type"-decrease.svg ;;
      *) image=${./assets}/audio-"$type"-default.svg ;;
    esac

    value=$(grep -o '[0-9]\.[0-9]*' <<< "$current_volume" || echo 0.0)
    value=$(${bc}/bin/bc <<< "scale=0; $value*100/1")
    if grep -q MUTED <<< "$current_volume"; then
      image=${./assets}/audio-"$type"-mute.svg
    fi

    if [[ "$value" -gt 100 ]]; then
      note=volume-overdrive
      indicator_value=$((value - 100))
    else
      note=volume
      indicator_value="$value"
    fi

    ${libnotify}/bin/notify-send \
      "Volume" "$value%" \
      --transient \
      --hint=string:image-path:"$image" \
      --hint=int:value:"$indicator_value" \
      --hint="string:wired-tag:indicator" \
      --hint="string:wired-note:$note" \
      --expire-time=1000 \
      || true
  '';
}
