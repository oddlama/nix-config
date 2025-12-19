{
  globals = {
    optModules = [
      ../modules/globals.nix
    ];
    defModules = [
      ../globals.nix
    ];
    attrkeys = [
      "domains"
      "hetzner"
      "kanidm"
      "macs"
      "mail"
      "monitoring"
      "malte"
      "net"
      "root"
      "services"
    ];
  };
}
