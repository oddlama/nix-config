{
  writeShellApplication,
  bc,
  libnotify,
  brightnessctl,
}:
writeShellApplication {
  name = "brightness";
  text = ''
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
      --transient \
      --hint=string:image-path:"$image" \
      --hint=int:value:"$value" \
      --expire-time=1000 \
      || true
  '';
}
