final: prev: {
  oauth2-proxy = prev.oauth2-proxy.overrideAttrs (_: {
    patches = [./0001-scopes-as-groups.patch];
  });
}
