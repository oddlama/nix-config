{
  config,
  lib,
  nixosConfig,
  ...
}: let
  inherit (lib) optionals;
in {
  home.persistence."/state".files =
    [
      # nothing yet ...
    ]
    ++ optionals config.programs.ssh.enable [
      ".ssh/known_hosts"
    ];

  home.persistence."/state".directories =
    [
      ".cache/fontconfig"
      ".cache/nix" # nix eval cache
      ".cache/nix-index"
    ]
    ++ optionals nixosConfig.hardware.nvidia.modesetting.enable [
      ".cache/nvidia" # GLCache
    ]
    ++ optionals nixosConfig.services.pipewire.enable [
      ".local/state/wireplumber"
    ];

  home.persistence."/persist".directories =
    [
      ".local/share/nix" # Repl history
    ]
    # TODO away once atuin is gone
    ++ optionals config.programs.atuin.enable [
      ".local/share/atuin"
    ]
    ++ optionals nixosConfig.programs.steam.enable [
      ".local/share/Steam"
      ".steam"
    ];
}
