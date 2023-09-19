{pkgs, ...}: {
  imports = [
    ./direnv.nix
    ./gdb.nix
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
