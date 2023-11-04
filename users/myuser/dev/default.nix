{pkgs, ...}: {
  imports = [
    ./direnv.nix
    ./gdb.nix
  ];

  persistence."/state".directories = [
    ".cargo"
  ];

  home = {
    extraOutputsToInstall = ["man" "doc" "devdoc"];
    packages = with pkgs; [
      git-lfs
      d2
      cloc
    ];
  };
}
