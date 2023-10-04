{
  lib,
  pkgs,
  ...
}: {extensions ? []}: let
  inherit
    (lib)
    boolToString
    concatMapStrings
    concatStringsSep
    escape
    length
    mapAttrsToList
    stringLength
    types
    ;

  toRon = indent: value:
    with builtins;
      if value == null
      then "None"
      else if isBool value
      then boolToString value
      else if isInt value || isFloat value
      then toString value
      else if isString value
      then string value
      else if isList value
      then list indent value
      else if isAttrs value
      then attrs indent value
      else abort "formats.ron: should never happen (value = ${value})";

  specialType = indent: {
    value,
    _ronType,
    ...
  } @ args:
    if _ronType == "literal"
    then value
    else if _ronType == "raw_string"
    then rawString value
    else if _ronType == "char"
    then char value
    else if _ronType == "optional"
    then some indent value
    else if _ronType == "tuple"
    then tuple indent value
    else if _ronType == "struct"
    then struct indent args
    else abort "formats.ron: should never happen (_ronType = ${_ronType})";

  escapedValues = escape ["\\" "\""];
  string = value: ''"${escapedValues value}"'';

  listContent = indent: values: concatStringsSep ",\n${indent}" (map (toRon indent) values);

  list = indent: values:
    if length values <= 1
    then "[${listContent indent values}]"
    else let newIndent = "${indent}\t"; in "[\n${newIndent}${listContent newIndent values}\n${indent}]";

  attrs = indent: set:
    if set ? _ronType
    then specialType indent set
    else let
      newIndent = "${indent}\t";
      toEntry = n: v: "${toRon newIndent n}: ${toRon newIndent v}";
      entries = concatStringsSep ",\n${newIndent}" (mapAttrsToList toEntry set);
    in "{\n${indent}${entries}\n${indent}}";

  rawString = value: ''r#"${value}"#'';
  char = value: "'${escapedValues value}'";
  some = indent: value: "Some(${toRon indent value})";
  tuple = indent: values: let
    newIndent = "${indent}\t";
  in "(\n${newIndent}${listContent newIndent values}\n${indent})";

  struct = indent: {
    name,
    value,
    ...
  }: let
    newIndent = "${indent}\t";
    toEntry = n: v: "${n}: ${toRon newIndent v}";
    entriesStr =
      if value ? _ronType
      then specialType indent value
      else let
        entries = mapAttrsToList toEntry value;
        entriesStrSpace = concatStringsSep ", " entries;
        entriesStrNl = "\n${newIndent}${concatStringsSep ",\n${newIndent}" entries}\n${indent}";
      in
        if stringLength (indent + entriesStrSpace) < 120
        then entriesStrSpace
        else entriesStrNl;
  in
    if stringLength name == 0
    then "(${entriesStr})"
    else "${name} (${entriesStr})";

  toFile = value: ''${concatMapStrings (x: "${x}\n") extensions}${toRon "" value}'';
in {
  type = let
    valueType =
      types.nullOr (types.oneOf [
        types.bool
        types.int
        types.float
        types.str
        (types.attrsOf valueType)
        (types.listOf valueType)
      ])
      // {
        description = "RON value";
      };
  in
    valueType;

  lib = let
    mkType = typeName: value: {
      inherit value;
      _ronType = typeName;
    };
  in rec {
    mkLiteral = mkType "literal";
    rawString = mkType "raw_string";
    char = mkType "character";
    some = mkType "optional";
    enum = mkLiteral;
    tuple = mkType "tuple";
    struct = name: value: {
      inherit value name;
      _ronType = "struct";
    };

    types = {};
  };

  generate = name: value:
    pkgs.runCommand name {
      value = toFile value;
      passAsFile = ["value"];
    } ''
      cp "$valuePath" "$out"
    '';
}
