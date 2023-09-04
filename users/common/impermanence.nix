{
  config,
  nixosConfig,
  ...
}: {
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
    ++ optionals config.programs.firefox.enable [
      ".cache/mozilla"
    ]
    ++ optionals config.programs.direnv.enable [
      ".local/share/direnv"
    ]
    ++ optionals config.programs.neovim.enable [
      ".local/share/nvim"
      ".local/state/nvim"
      ".cache/nvim"
    ]
    ++ optionals nixosConfig.hardware.nvidia.enable [
      ".cache/nvidia" # GLCache
    ]
    ++ optionals nixosConfig.services.pipewire.enable [
      ".local/state/wireplumber"
    ];

  home.persistence."/persist".directories =
    [
      ".local/share/nix" # Repl history
    ]
    ++ optionals config.programs.firefox.enable [
      ".mozilla"
    ]
    ++ optionals config.programs.atuin.enable [
      ".local/share/atuin"
    ]
    ++ optionals nixosConfig.programs.steam.enable [
      ".local/share/Steam"
      ".steam"
    ];
}
