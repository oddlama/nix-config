{
  users.mutableUsers = false;

  users.deterministicIds = let
    uidGid = id: {
      uid = id;
      gid = id;
    };
  in {
    systemd-oom = uidGid 999;
    systemd-coredump = uidGid 998;
    sshd = uidGid 997;
    nscd = uidGid 996;
    polkituser = uidGid 995;
    microvm = uidGid 994;
    promtail = uidGid 993;
    grafana = uidGid 992;
    acme = uidGid 991;
    kanidm = uidGid 990;
    loki = uidGid 989;
    vaultwarden = uidGid 988;
    oauth2_proxy = uidGid 987;
    influxdb2 = uidGid 986;
    telegraf = uidGid 985;
    rtkit = uidGid 984;
    git = uidGid 983;
    redis-paperless = uidGid 982;
    nixseparatedebuginfod = uidGid 981;
    msr = uidGid 980;
    fwupd-refresh = uidGid 979;
    radicale = uidGid 978;
    podman = uidGid 977;
    maddy = uidGid 976;
  };
}
