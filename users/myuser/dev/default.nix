{pkgs, ...}: {
  imports = [
    ./direnv.nix
    ./gdb.nix
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
    ];
  };
}
