{ globals, ... }:
{
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/blog";
      mode = "0750";
      user = "nginx";
      group = "nginx";
    }
  ];

  services.nginx.virtualHosts.${globals.domains.me} = {
    forceSSL = true;
    useACMEWildcardHost = true;
    locations."/".root = "/var/lib/blog";
    # Don't use the proxyPass option because we don't want the recommended proxy headers
    locations."= /js/script.js".extraConfig = ''
      proxy_pass https://${globals.services.plausible.domain}/js/script.js;
      proxy_ssl_server_name on;
      proxy_set_header Host ${globals.services.plausible.domain};
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
      proxy_set_header X-Forwarded-Host $host;
      proxy_set_header X-Forwarded-Server $host;
    '';
    locations."= /api/event".extraConfig = ''
      proxy_pass https://${globals.services.plausible.domain}/api/event;
      proxy_http_version 1.1;
      proxy_ssl_server_name on;
      proxy_set_header Host ${globals.services.plausible.domain};
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
      proxy_set_header X-Forwarded-Host $host;
      proxy_set_header X-Forwarded-Server $host;
    '';
  };
}
