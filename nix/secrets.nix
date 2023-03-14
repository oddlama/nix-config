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
} @ inputs:
with nixpkgs.lib; let
  mergeArray = f: unique (concatLists (mapAttrsToList (_: f) self.nodes));
  mergedMasterIdentities = mergeArray (x: x.config.rekey.masterIdentities or []);
  # "Imports" an encrypted .nix.age file
  importEncrypted = path:
    if builtins.pathExists path
    then builtins.extraBuiltins.rageImportDecrypt mergedMasterIdentities path
    else _: {};
in
  (importEncrypted ../secrets/secrets.nix.age inputs)
  // {
    nodes = mapAttrs (hostName: _: importEncrypted ../hosts/${hostName}/secrets/secrets.nix.age inputs) self.nodes;
  }
