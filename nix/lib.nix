{nixpkgs, ...}: let
  inherit
    (nixpkgs.lib)
    filter
    foldl'
    unique
    ;
in rec {
  # Counts how often each element occurrs in xs
  countOccurrences = xs: let
    addOrUpdate = acc: x:
      if builtins.hasAttr x acc
      then acc // {${x} = acc.${x} + 1;}
      else acc // {${x} = 1;};
  in
    foldl' addOrUpdate {} xs;

  # Returns all elements in xs that occur at least once
  duplicates = xs: let
    occurrences = countOccurrences xs;
  in
    unique (filter (x: occurrences.${x} > 1) xs);
}
