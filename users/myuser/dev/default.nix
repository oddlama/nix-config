{pkgs, ...}: {
  imports = [
    ./direnv.nix
    ./gdb.nix
  ];

  home = {
    extraOutputsToInstall = ["doc" "devdoc"];
    packages = with pkgs; [
      git-lfs
      d2
      cloc
    ];
  };

  programs.nix-index.enable = true;
}
