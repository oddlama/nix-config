{
  writeShellApplication,
  bc,
  libnotify,
  brightnessctl,
}:
writeShellApplication {
  name = "brightness";
  text = ''
    set -euo pipefail

    ${brightnessctl}/bin/brightnessctl "$1" "$2"
    case "$2" in
      "+"*) image=${./assets}/brightness-increase.svg ;;
      *"-") image=${./assets}/brightness-decrease.svg ;;
    esac

    max=$(${brightnessctl}/bin/brightnessctl -m max)
    value=$(${brightnessctl}/bin/brightnessctl -m get)
    value=$(${bc}/bin/bc <<< "scale=0; 100*$value/$max")
    ${libnotify}/bin/notify-send \
      "Brightness" \
      --hint=string:image-path:"$image" \
      --hint=int:value:"$value" \
      --hint="string:wired-tag:indicator" \
      --hint="string:wired-note:brightness" \
      --expire-time=1000 \
      || true
  '';
}
