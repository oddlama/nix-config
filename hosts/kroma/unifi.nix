# { lib, ... }:
{
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/unifi";
      mode = "0700";
      user = "unifi";
      group = "unifi";
    }
  ];

  # services.unifi.enable = true;

  # Don't autostart.
  # systemd.services.unifi.wantedBy = lib.mkForce [ ];
}
