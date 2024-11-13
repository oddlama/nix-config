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
      (pkgs.python3.withPackages (p: with p; [numpy]))
      pkgs.cloc
      pkgs.d2
      pkgs.gh
      pkgs.gh-dash
      pkgs.git-lfs
      pkgs.jq
    ];
  };
}
