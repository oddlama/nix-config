_self: super: {
  oauth2-proxy = super.oauth2-proxy.overrideAttrs (_: {
    patches = [./0001-scopes-as-groups.patch];
  });
}
