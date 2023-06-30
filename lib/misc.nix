inputs: let
  inherit
    (inputs.nixpkgs.lib)
    all
    any
    assertMsg
    attrNames
    attrValues
    concatLists
    concatMap
    concatMapStrings
    concatStringsSep
    elem
    escapeShellArg
    filter
    flatten
    flip
    foldAttrs
    foldl'
    genAttrs
    genList
    hasInfix
    head
    isAttrs
    mapAttrs'
    mergeAttrs
    min
    mkMerge
    mkOptionType
    nameValuePair
    optionalAttrs
    partition
    range
    recursiveUpdate
    removeSuffix
    reverseList
    showOption
    splitString
    stringToCharacters
    substring
    types
    unique
    warnIf
    ;
in rec {
  # Counts how often each element occurrs in xs
  countOccurrences = let
    addOrUpdate = acc: x:
      acc // {${x} = (acc.${x} or 0) + 1;};
  in
    foldl' addOrUpdate {};

  # Returns all elements in xs that occur at least twice
  duplicates = xs: let
    occurrences = countOccurrences xs;
  in
    unique (filter (x: occurrences.${x} > 1) xs);

  # Concatenates all given attrsets as if calling a // b in order.
  concatAttrs = foldl' mergeAttrs {};

  # True if the path or string starts with /
  isAbsolutePath = x: substring 0 1 x == "/";

  # Merges all given attributes from the given attrsets using mkMerge.
  # Useful to merge several top-level configs in a module.
  mergeToplevelConfigs = keys: attrs:
    genAttrs keys (attr: mkMerge (map (x: x.${attr} or {}) attrs));

  # Calculates base^exp, but careful, this overflows for results > 2^62
  pow = base: exp: foldl' (a: x: x * a) 1 (genList (_: base) exp);

  # Converts the given hex string to an integer. Only reliable for inputs in [0, 2^63),
  # after that the sign bit will overflow.
  hexToDec = v: let
    literalValues = {
      "0" = 0;
      "1" = 1;
      "2" = 2;
      "3" = 3;
      "4" = 4;
      "5" = 5;
      "6" = 6;
      "7" = 7;
      "8" = 8;
      "9" = 9;
      "a" = 10;
      "b" = 11;
      "c" = 12;
      "d" = 13;
      "e" = 14;
      "f" = 15;
      "A" = 10;
      "B" = 11;
      "C" = 12;
      "D" = 13;
      "E" = 14;
      "F" = 15;
    };
  in
    foldl' (acc: x: acc * 16 + literalValues.${x}) 0 (stringToCharacters v);

  secrets = let
    rageMasterIdentityArgs = concatMapStrings (x: "-i ${escapeShellArg x} ") inputs.self.secretsConfig.masterIdentities;
    rageExtraEncryptionPubkeys =
      concatMapStrings (
        x:
          if isAbsolutePath x
          then "-R ${escapeShellArg x} "
          else "-r ${escapeShellArg x} "
      )
      inputs.self.secretsConfig.extraEncryptionPubkeys;
  in {
    # TODO replace these by lib.agenix-rekey
    # The arguments required to de-/encrypt a secret in this repository
    rageDecryptArgs = "${rageMasterIdentityArgs}";
    rageEncryptArgs = "${rageMasterIdentityArgs} ${rageExtraEncryptionPubkeys}";
  };
}
