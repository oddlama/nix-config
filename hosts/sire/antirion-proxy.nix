# Shared by both nginx frontends and the gateway integration test.
{
  domain,
  upstream,
  # Set { upstream, allow } to route the admin console and API to the admin
  # listener `upstream` for clients in the `allow` networks only. Leave null on
  # every frontend that must not expose the admin plane.
  admin ? null,
}:
let
  adminLocation = {
    proxyPass = "http://antirion-admin";
    extraConfig = ''
      ${builtins.concatStringsSep "\n" (map (network: "allow ${network};") admin.allow)}
      deny all;
    '';
  };
in
{
  upstreams = {
    antirion = {
      servers.${upstream} = { };
      extraConfig = ''
        zone antirion 64k;
        keepalive 8;
      '';
    };
  }
  // (
    if admin == null then
      { }
    else
      {
        antirion-admin = {
          servers.${admin.upstream} = { };
          extraConfig = ''
            zone antirion-admin 64k;
            keepalive 2;
          '';
        };
      }
  );

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
      # Everything else, in particular the backend UIs and (without `admin`)
      # the admin plane, stays unrouted.
      "/" = {
        return = "404";
      };
    }
    // (
      if admin == null then
        { }
      else
        {
          # The console is built for /ui and calls the Admin API on its own origin.
          "/ui/" = adminLocation;
          "/admin/v1/" = adminLocation;
        }
    );
  };
}
