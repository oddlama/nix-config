{nixpkgs, ...}:
nixpkgs.lib.concatMapAttrs (hostName: fileType:
    if fileType == "directory"
    then {${hostName} = import (../hosts + "/${hostName}/meta.nix");}
    else {}) (builtins.readDir ../hosts)
