# Shared by both nginx frontends and the gateway integration test.
{ domain, upstream }:
{
  upstreams.antirion = {
    servers.${upstream} = { };
    extraConfig = ''
      zone antirion 64k;
      keepalive 8;
    '';
  };

  virtualHosts.${domain} = {
    extraConfig = ''
      client_max_body_size 128M;
      proxy_read_timeout 900s;
      proxy_send_timeout 900s;
      # Chat SSE and audio must not wait for nginx response buffering.
      proxy_buffering off;
    '';
    locations = {
      "/v1/" = {
        proxyPass = "http://antirion";
      };
      "/oxr/" = {
        proxyPass = "http://antirion";
      };
      # OXR returns root-relative /v1/artifacts/... URLs. These must go through
      # the same authenticated passthrough as parsing, never straight to OXR.
      "/v1/artifacts/" = {
        proxyPass = "http://antirion/oxr/v1/artifacts/";
      };
      # In particular, do not expose the admin API, console, or backend UIs.
      "/" = {
        return = "404";
      };
    };
  };
}
