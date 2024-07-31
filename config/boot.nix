{
  config,
  globals,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf (!config.boot.isContainer) {
    boot = {
      initrd.systemd = {
        enable = true;
        emergencyAccess = globals.root.hashedPassword;
        # TODO good idea? targets.emergency.wants = ["network.target" "sshd.service"];
        extraBin.ip = "${pkgs.iproute2}/bin/ip";
        extraBin.ping = "${pkgs.iputils}/bin/ping";
        extraBin.cryptsetup = "${pkgs.cryptsetup}/bin/cryptsetup";
        # Give me a usable shell please
        users.root.shell = "${pkgs.bashInteractive}/bin/bash";
        storePaths = ["${pkgs.bashInteractive}/bin/bash"];
      };

      # NOTE: Add "rd.systemd.unit=rescue.target" to debug initrd
      kernelParams = ["log_buf_len=16M"]; # must be {power of two}[KMG]
      tmp.useTmpfs = true;

      loader.timeout = lib.mkDefault 2;
    };

    console.earlySetup = true;
  };
}
