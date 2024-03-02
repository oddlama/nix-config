{
  pkgs,
  fetchurl,
}: let
  name = "awakened-poe-trade";
  version = "3.22.10003";
  description = "Path of Exile trading app for price checking";
  desktopEntry = pkgs.writeText "awakened-poe.desktop" ''
    [Desktop Entry]
    Type=Application
    Version=${version}
    Name=Awakened PoE Trade
    GenericName=${description}
    Icon=/share/applications/awakened-poe-trade.png
    Exec=${name}
    Terminal=false
    Categories=Game
  '';
  file = "Awakened-PoE-Trade-${version}.AppImage";

  icon = pkgs.fetchurl {
    url = "https://web.poecdn.com/image/Art/2DItems/Currency/TransferOrb.png";
    sha256 = "sha256-/PydWTOU2SIjATfYYk7HEHBlssvb52dr/LkyBwzZPp8=";
  };
in
  pkgs.appimageTools.wrapType2 {
    name = "awakened-poe-trade";
    src = fetchurl {
      url = "https://github.com/SnosMe/awakened-poe-trade/releases/download/v${version}/${file}";
      hash = "sha256-b+cDOmU0s0MqP5ZgCacmAon8UqDejG4HcOqi+Uf2dEM=";
    };

    extraInstallCommands = ''
      mkdir -p $out/share/applications
      cp ${icon} $out/share/applications/awakened-poe-trade.png
      cp ${desktopEntry} $out/share/applications/${name}.desktop
      substituteInPlace $out/share/applications/awakened-poe-trade.desktop --replace /share/ $out/share/
    '';
  }
