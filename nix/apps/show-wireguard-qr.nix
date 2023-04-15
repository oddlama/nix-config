{
  self,
  pkgs,
  ...
} @ inputs: let
  inherit
    (pkgs.lib)
    attrNames
    concatMap
    concatStringsSep
    escapeShellArg
    unique
    ;

  nodeNames = attrNames self.nodes;
  wireguardNetworks = unique (concatMap (n: attrNames self.nodes.${n}.config.extra.wireguard) nodeNames);

  externalPeersForNet = wgName:
    concatMap (serverNode:
      map
      (peer: {inherit wgName serverNode peer;})
      (attrNames self.nodes.${serverNode}.config.extra.wireguard.${wgName}.server.externalPeers))
    (self.extraLib.wireguard wgName).associatedServerNodes;
  allExternalPeers = concatMap externalPeersForNet wireguardNetworks;
in
  pkgs.writeShellScript "show-wireguard-qr" ''
    set -euo pipefail
    json_sel=$(echo ${escapeShellArg (concatStringsSep "\n" (map (x: "${builtins.toJSON x}\t[33m${x.wgName}[m.[34m${x.serverNode}[m.[32m${x.peer}[m") allExternalPeers))} \
      | ${pkgs.fzf}/bin/fzf --delimiter='\t' --ansi --multi --query="''${1-}" --tiebreak=end --bind=tab:down,btab:up,change:top,ctrl-space:toggle --with-nth=2.. --height='~50%' --tac \
      | ${pkgs.coreutils}/bin/cut -d$'\t' -f1)
    [[ -n "$json_sel" ]] || exit 1

    while IFS= read -r line; do
      wgName=$(${pkgs.jq}/bin/jq -r .wgName <<< "$line")
      serverNode=$(${pkgs.jq}/bin/jq -r .serverNode <<< "$line")
      peer=$(${pkgs.jq}/bin/jq -r .peer <<< "$line")
      echo "======== $wgName.$serverNode.$peer ========"

      createConfigScript=$(nix build --no-link --print-out-paths --impure --show-trace --expr \
        'let flk = builtins.getFlake "${../../.}"; in (flk.extraLib.wireguard "'"$wgName"'").wgQuickConfigScript "${pkgs.system}" "'"$serverNode"'" "'"$peer"'"')
      "$createConfigScript" | tee /dev/tty | ${pkgs.qrencode}/bin/qrencode -t ansiutf8
    done <<< "$json_sel"
  ''
