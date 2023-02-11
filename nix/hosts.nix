{nixpkgs, ...}:
nixpkgs.lib.concatMapAttrs (nodeName: fileType:
    if fileType == "directory"
    then {${nodeName} = import (../hosts + "/${nodeName}/meta.nix");}
    else {}) (builtins.readDir ../hosts)
