{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf (!config.boot.isContainer) {
    boot = {
      initrd.systemd = {
        enable = true;
        emergencyAccess = config.repo.secrets.global.root.hashedPassword;
        # TODO good idea? targets.emergency.wants = ["network.target" "sshd.service"];
        extraBin.ip = "${pkgs.iproute2}/bin/ip";
      };

      # NOTE: Add "rd.systemd.unit=rescue.target" to debug initrd
      kernelParams = ["log_buf_len=16M"]; # must be {power of two}[KMG]
      tmp.useTmpfs = true;

      loader.timeout = lib.mkDefault 2;
    };

    console.earlySetup = true;
  };
}
