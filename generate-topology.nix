{
  pkgs,
  # deadnix: skip
  renderer ? "graphviz",
  nixosConfigurations,
}: let
  inherit
    (pkgs.lib)
    any
    attrNames
    attrValues
    concatLines
    concatStringsSep
    elem
    escapeXML
    flip
    filterAttrs
    imap0
    mapAttrs'
    nameValuePair
    mapAttrsToList
    optional
    optionalAttrs
    optionalString
    ;

  # global = {
  #   # global entities;
  # };

  # asjson = builtins.toFile "topology.dot" (
  #   builtins.toJSON (map (x: x.config.topology) (attrValues nixosConfigurations))
  # );

  colors.base00 = "#101419";
  colors.base01 = "#171B20";
  colors.base02 = "#21262e";
  colors.base03 = "#242931";
  colors.base03b = "#353c48";
  colors.base04 = "#485263";
  colors.base05 = "#b6beca";
  colors.base06 = "#dee1e6";
  colors.base07 = "#e3e6eb";
  colors.base08 = "#e05f65";
  colors.base09 = "#f9a872";
  colors.base0A = "#f1cf8a";
  colors.base0B = "#78dba9";
  colors.base0C = "#74bee9";
  colors.base0D = "#70a5eb";
  colors.base0E = "#c68aee";
  colors.base0F = "#9378de";

  nodesById = mapAttrs' (_: node: nameValuePair node.config.topology.id node) nixosConfigurations;

  xmlAttrs = attrs: concatStringsSep " " (mapAttrsToList (n: v: "${n}=\"${v}\"") attrs);
  font = attrs: text: "<font ${xmlAttrs attrs}>${text}</font>";
  fontMono = {face = "JetBrains Mono";};
  mono = font fontMono;
  monoColor = color: font (fontMono // {inherit color;});

  mkCell = cellAttrs: text: "<td ${xmlAttrs cellAttrs}>${text}</td>";
  mapToTableRows = xs: {
    columnOrder,
    columns,
    titleRow ? true,
    titleRowColor ? colors.base0C,
    titleRowAttrs ? {bgcolor = titleRowColor;},
    alternateRowAttrs ? {bgcolor = colors.base03b;},
  }:
    concatLines (
      optional titleRow "<tr>${concatStringsSep "" (flip map columnOrder (c: mkCell titleRowAttrs "<b>${mono columns.${c}.title}</b>"))}</tr>"
      ++ flip imap0 xs (
        i: x: "<tr>${concatStringsSep "" (flip map columnOrder (c:
          mkCell
          (optionalAttrs (pkgs.lib.mod i 2 == 1) alternateRowAttrs // (columns.${c}.cellAttrs or {}))
          (columns.${c}.transform x.${c})))}</tr>"
      )
    );

  mkTable = xs: settings: ''
    <table border="0" cellborder="0" cellspacing="0" cellpadding="4" bgcolor="${colors.base03}" color="${colors.base04}">
    ${mapToTableRows xs settings}
    </table>
  '';

  nodeId = str: "\"${escapeXML str}\"";
  isGuestOfAny = node: any (x: elem node x.config.topology.guests) (attrValues nodesById);
  rootNodes = filterAttrs (n: _: !(isGuestOfAny n)) nodesById;

  toDot = node: let
    topo = node.config.topology;

    diskTable = mkTable (attrValues topo.disks) {
      titleRowColor = colors.base0F;
      columnOrder = ["name"];
      columns = {
        name = {
          title = "Name";
          transform = mono;
        };
      };
    };

    interfaceTable = mkTable (attrValues topo.interfaces) {
      titleRowColor = colors.base0D;
      columnOrder = ["name" "mac" "addresses"];
      columns = {
        name = {
          title = "Name";
          transform = x:
            if x == null
            then ""
            else mono x;
        };
        mac = {
          title = "MAC";
          transform = x:
            if x == null
            then ""
            else monoColor colors.base09 x;
        };
        addresses = {
          title = "Addr";
          transform = xs: mono (concatStringsSep " " xs);
        };
      };
    };
  in
    ''
      subgraph ${nodeId "cluster_${topo.id}"} {
        color = "${colors.base04}";

        ${nodeId topo.id} [label=<
          <table border="0" cellborder="0" cellspacing="0" cellpadding="4" bgcolor="${colors.base03}" color="${colors.base04}">
            <tr><td bgcolor="${colors.base08}"><b>${mono "Attribute"}</b></td><td bgcolor="${colors.base08}"><b>${mono "Value"}</b></td></tr>
            <tr><td>${mono "id"}</td><td>${mono topo.id}</td></tr>
            <tr><td>${mono "type"}</td><td>${mono topo.type}</td></tr>
          </table>
        >];

        {
          rank = "same";
          ${nodeId "${topo.id}.disks"} [label=<
            ${diskTable}
          >];
          ${nodeId "${topo.id}.interfaces"} [label=<
            ${interfaceTable}
          >];
        }

        ${nodeId topo.id} -> ${nodeId "${topo.id}.disks"} [label="disks", color="${colors.base05}", fontcolor="${colors.base06}"];
        ${nodeId topo.id} -> ${nodeId "${topo.id}.interfaces"} [label="interfaces", color="${colors.base05}", fontcolor="${colors.base06}"];
    ''
    + optionalString (topo.guests != []) ''
        subgraph ${nodeId "cluster_guests_${topo.id}"} {
          color = "${colors.base04}";
          {
            rank = "same";
            ${concatLines (map (guest: "${nodeId guest};") topo.guests)}
          }

          ${concatLines (map (guest: dotForNodes.${guest}) topo.guests)}
        };

        ${concatLines (map (guest: "${nodeId topo.id} -> ${nodeId guest} [color=\"${colors.base05}\"];") topo.guests)}
      }
    ''
    + optionalString (!isGuestOfAny topo.id) ''
      root -> ${nodeId topo.id} [color="${colors.base05}"];
    '';

  dotForNodes = mapAttrs' (_: node: nameValuePair node.config.topology.id (toDot node)) nodesById;
in
  pkgs.writeText "topology.dot" ''
    digraph G {
      graph [rankdir=TB, splines=spline, bgcolor="${colors.base00}"];
      node [shape=plaintext, fontcolor="${colors.base06}", color="${colors.base06}"];

      ${concatLines (map (x: dotForNodes.${x}) (attrNames rootNodes))}
    }
  ''
