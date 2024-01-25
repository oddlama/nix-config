{
  microvm.mem = 1024 * 16;
  microvm.vcpu = 20;

  networking.firewall.allowedTCPPorts = [11434];

  environment.persistence."/state".directories = [
    {
      directory = "/var/lib/private/ollama";
      mode = "0700";
    }
  ];

  services.ollama = {
    enable = true;
    listenAddress = "0.0.0.0:11434";
  };
}
