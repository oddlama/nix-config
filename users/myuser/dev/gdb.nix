{pkgs, ...}: let
  # pwndbg wraps a gdb binary for us, but we want debuginfod in there too.
  # Also make it the default gdb.
  pwndbgWithDebuginfod =
    (pkgs.pwndbg.override {
      gdb =
        (pkgs.gdb.override {
          enableDebuginfod = true;
        })
        .overrideAttrs (_finalAttrs: previousAttrs: {
          patches =
            previousAttrs.patches
            ++ [
              ./0001-gdb-show-libraries-in-coredump-backtrace.patch
            ];
        });
    })
    .overrideAttrs (_finalAttrs: previousAttrs: {
      installPhase =
        previousAttrs.installPhase
        + ''
          ln -s $out/bin/pwndbg $out/bin/gdb
        '';
    });
in {
  home.packages = builtins.trace "WARN: reenable pwndbg later!" [
    #pwndbgWithDebuginfod
    pkgs.hotspot
  ];

  home.file.gdbinit = {
    target = ".gdbinit";
    text = ''
      set auto-load safe-path /
      set debuginfod enabled on

      set history save on
      set history filename ~/.local/share/gdb/history

      set disassembly-flavor intel
      set print pretty on
    '';
  };

  home.persistence."/state".directories = [
    ".local/share/gdb"
  ];
}
