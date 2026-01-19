{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    optionals
    ;
in
{
  # Give agenix access to the hostkey independent of impermanence activation
  age.identityPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];

  # State that should be kept across reboots, but is otherwise
  # NOT important information in any way that needs to be backed up.
  fileSystems."/state".neededForBoot = true;
  environment.persistence."/state" = {
    hideMounts = true;
    directories = [
      "/var/lib/systemd"
      "/var/log"
      "/var/spool"
      #{ directory = "/tmp"; mode = "1777"; }
      #{ directory = "/var/tmp"; mode = "1777"; }
    ]
    ++ optionals config.networking.wireless.iwd.enable [
      {
        directory = "/var/lib/iwd";
        mode = "0700";
      }
    ];
  };

  # State that should be kept forever, and backed up accordingly.
  fileSystems."/persist".neededForBoot = true;
  environment.persistence."/persist" = {
    hideMounts = true;
    files = [
      # For ephemeral nixos-containers we cannot link the /etc/machine-id file,
      # because it will be generated based on a stable container uuid.
      (lib.mkIf (!config.boot.isContainer) "/etc/machine-id")
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
    ];
    directories = [
      "/var/lib/nixos"
    ]
    ++ optionals config.security.acme.acceptTerms [
      {
        directory = "/var/lib/acme";
        user = "acme";
        group = "acme";
        mode = "0755";
      }
    ]
    ++ optionals config.services.printing.enable [
      {
        directory = "/var/lib/cups";
        mode = "0755";
      }
    ]
    ++ optionals config.services.postgresql.enable [
      {
        directory = "/var/lib/postgresql";
        user = "postgres";
        group = "postgres";
        mode = "0700";
      }
    ];
  };
}
