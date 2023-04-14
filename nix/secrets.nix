# This file manages access to repository-secrets. Anything that is technically
# not a secret on your hosts, but something you want to keep secret from the public.
# Anything you don't want people to see on GitHub that isn't a password or encrypted
# using agenix.
#
# All of these secrets may (and probably will be) put into the world-readable nix-store
# on the build and target hosts. You'll most likely want to store personally identifiable
# information here, such as:
#   - MAC Addreses
#   - Static IP addresses
#   - Your full name (when configuring e.g. users)
#   - Your postal address (when configuring e.g. home-assistant)
#   - ...
{
  self,
  nixpkgs,
  ...
} @ inputs: let
  inherit
    (nixpkgs.lib)
    mapAttrs
    ;
  # If the given expression is a bare set, it will be wrapped in a function,
  # so that the imported file can always be applied to the inputs, similar to
  # how modules can be functions or sets.
  constSet = x:
    if builtins.isAttrs x
    then (_: x)
    else x;
  # This "imports" an encrypted .nix.age file
  importEncrypted = path:
    constSet (
      if builtins.pathExists path
      then builtins.extraBuiltins.rageImportEncrypted self.secrets.masterIdentities path
      else {}
    );
in
  (importEncrypted ../secrets/secrets.nix.age inputs)
  // {
    nodes = mapAttrs (hostName: _: importEncrypted ../hosts/${hostName}/secrets/secrets.nix.age inputs) self.hosts;
  }
