{pkgs, ...}: {
  imports = [
    ./direnv.nix
    ./gdb.nix
    ./manpager.nix
  ];

  home = {
    sessionVariables.CARGO_HOME = "\${HOME}/.local/share/cargo";
    sessionVariables.RUSTUP_HOME = "\${HOME}/.local/share/rustup";
    persistence."/state".directories = [
      ".local/share/cargo"
      ".local/share/rustup"
    ];

    extraOutputsToInstall = ["man" "doc" "devdoc"];
    packages = [
      pkgs.git-lfs
      pkgs.d2
      pkgs.cloc
      pkgs.jq
      pkgs.python3
    ];
  };
}
