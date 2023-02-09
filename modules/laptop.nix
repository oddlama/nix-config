{pkgs, ...}: {
  environment.systemPackages = with pkgs; [powertop];
  services.physlock.enable = true;
  services.logind = {
    lidSwitch = "ignore";
    lidSwitchDocked = "ignore";
    lidSwitchExternalPower = "ignore";
    extraConfig = ''
      HandlePowerKey=suspend
      HandleSuspendKey=suspend
      HandleHibernateKey=suspend
      PowerKeyIgnoreInhibited=yes
      SuspendKeyIgnoreInhibited=yes
      HibernateKeyIgnoreInhibited=yes
    '';
  };
}
