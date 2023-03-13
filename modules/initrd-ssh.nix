{
  config,
  name,
  ...
}: {
  rekey.secrets.initrd_host_ed25519_key.file = ../hosts/${name}/initrd_host_ed25519_key.age;

  boot.initrd.network.enable = true;
  boot.initrd.network.ssh = {
    enable = true;
    port = 4;
    hostKeys = [config.rekey.secrets.initrd_host_ed25519_key.path];
  };
}
