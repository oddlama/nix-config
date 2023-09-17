{
  config,
  lib,
  nixosConfig,
  ...
}: let
  inherit (lib) optionals;
in {
  home.persistence."/state".files = optionals config.programs.ssh.enable [
    ".ssh/known_hosts"
  ];

  home.persistence."/state".directories =
    [
      ".cache/fontconfig"
      ".cache/nix" # nix eval cache
      ".cache/nix-index"
      ".config/dconf" # some apps store their configuration using dconf
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
    ++ optionals nixosConfig.programs.steam.enable [
      ".local/share/Steam"
      ".steam"
    ];
}
