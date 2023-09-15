{ pkgs, ... }: let
  # pwndbg wraps a gdb binary for us, but we want debuginfod in there too.
  # Also make it the default gdb.
  pwndbgWithDebuginfod = (pkgs.pwndbg.override {
    gdb = pkgs.gdb.override {
      enableDebuginfod = true;
    };
  }).overrideAttrs (_finalAttrs: previousAttrs: {
    installPhase = previousAttrs.installPhase + ''
      ln -s $out/bin/pwndbg $out/bin/gdb
    '';
  });
in {
  home.packages = [
    pwndbgWithDebuginfod
    pkgs.hotspot
  ];

  home.file.gdbinit = {
    target = ".gdbinit";
    text = ''
      set debuginfod enabled on
      set auto-load safe-path /
      set disassembly-flavor intel
      set history save on
      set print pretty on
    '';
  };
}
