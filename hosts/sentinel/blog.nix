{
  globals,
  pkgs,
  ...
}: {
  services.nginx.virtualHosts.${globals.domains.me} = {
    forceSSL = true;
    useACMEWildcardHost = true;
    locations."/".root = pkgs.runCommand "index.html" {} ''
      mkdir -p $out
      cat > $out/index.html <<EOF
      <html>
        <head>
        	<script defer data-api="/api/event" data-domain="oddlama.org" src="/js/script.js"></script>
        </head>
        <body>Not empty soon TM. Until then please go here: <a href="https://github.com/oddlama">oddlama</a></body>
      </html>
      EOF
    '';
    # Don't use the proxyPass option because we don't want the recommended proxy headers
    locations."= /js/script.js".extraConfig = ''
      proxy_pass https://${globals.services.plausible.domain}/js/script.js;
      proxy_set_header Host ${globals.services.plausible.domain};
      proxy_ssl_server_name on;
    '';
    locations."= /api/event".extraConfig = ''
      proxy_pass https://${globals.services.plausible.domain}/api/event;
      proxy_http_version 1.1;
      proxy_set_header Host ${globals.services.plausible.domain};
      proxy_ssl_server_name on;
    '';
  };
}
