{pkgs, ...}: {
  imports = [
    ./direnv.nix
    ./gdb.nix
    ./manpager.nix
  ];

  home = {
    persistence."/state".directories = [
      ".cargo"
    ];

    extraOutputsToInstall = ["man" "doc" "devdoc"];
    packages = with pkgs; [
      git-lfs
      d2
      cloc
      jq
      python3
    ];
  };
}
