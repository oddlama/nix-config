{
  lib,
  config,
  ...
}: {
  age.secrets."selfcert.crt" = {
    rekeyFile = ./secrets/selfcert.crt.age;
    mode = "440";
    group = "nginx";
  };
  age.secrets."selfcert.key" = {
    rekeyFile = ./secrets/selfcert.key.age;
    mode = "440";
    group = "nginx";
  };

  #security.acme.acceptTerms = true;
  #security.acme.defaults.email = "admin+acme@example.com";
  services.nginx.enable = true;
}
