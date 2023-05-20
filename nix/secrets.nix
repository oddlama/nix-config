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
    attrNames
    concatMap
    filterAttrs
    listToAttrs
    mapAttrs
    nameValuePair
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

  # Secrets for each physical node
  nodeSecrets = mapAttrs (nodeName: _: importEncrypted ../hosts/${nodeName}/secrets/secrets.nix.age inputs) self.hosts;

  # A list of all nodes that have microvm directories
  nodesWithMicrovms = builtins.filter (nodeName: builtins.pathExists ../hosts/${nodeName}/microvms) (attrNames self.hosts);
  # Returns a list of all microvms defined for the given node
  microvmsFor = nodeName:
    attrNames (filterAttrs
      (_: t: t == "directory")
      (builtins.readDir ../hosts/${nodeName}/microvms));
  # Returns all defined microvms with name and definition for a given node
  microvmDefsFor = nodeName:
    map
    # TODO This is duplicated three times. This is microvm naming #2
    (microvmName: nameValuePair "${nodeName}-${microvmName}" ../hosts/${nodeName}/microvms/${microvmName})
    (microvmsFor nodeName);
  # A attrset mapping all microvm nodes to its definition folder
  microvms = listToAttrs (concatMap microvmDefsFor nodesWithMicrovms);
  # The secrets for each microvm
  microvmSecrets = mapAttrs (microvmName: microvmPath: importEncrypted (microvmPath + "/secrets/secrets.nix.age") inputs) microvms;
in
  (importEncrypted ../secrets/secrets.nix.age inputs)
  // {nodes = nodeSecrets // microvmSecrets;}
