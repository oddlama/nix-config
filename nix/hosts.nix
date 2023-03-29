{nixpkgs, ...}: let
  hostDefaults = {
    physicalConnections = {};
    microVmHost = false;
  };
in
  nixpkgs.lib.concatMapAttrs (nodeName: fileType:
    if fileType == "directory" && nodeName != "common"
    then {${nodeName} = hostDefaults // import (../hosts + "/${nodeName}/meta.nix");}
    else {}) (builtins.readDir ../hosts)
