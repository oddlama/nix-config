{
  systemd.network.wait-online.anyInterface = true;

  # services.tlp.enable = true;
  services.physlock.enable = true;
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandlePowerKey = "ignore";
    HandleSuspendKey = "suspend";
    HandleHibernateKey = "suspend";
    PowerKeyIgnoreInhibited = "yes";
    SuspendKeyIgnoreInhibited = "yes";
    HibernateKeyIgnoreInhibited = "yes";
  };
}
