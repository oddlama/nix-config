{
  systemd.network.wait-online.anyInterface = true;

  # services.tlp.enable = true;
  services.physlock.enable = true;
  services.logind.settings.Login = {
    LidSwitch = "ignore";
    LidSwitchDocked = "ignore";
    LidSwitchExternalPower = "ignore";
    HandlePowerKey = "suspend";
    HandleSuspendKey = "suspend";
    HandleHibernateKey = "suspend";
    PowerKeyIgnoreInhibited = "yes";
    SuspendKeyIgnoreInhibited = "yes";
    HibernateKeyIgnoreInhibited = "yes";
  };
}
