{pkgs, ...}: {
  # Make sure not to reference the extra-builtins file directly but
  # at least via its parent folder so it can access relative files.
  nix.extraOptions = ''
    plugin-files = ${pkgs.nix-plugins}/lib/nix/plugins
    extra-builtins-file = ${../../../nix}/extra-builtins.nix
  '';
}
