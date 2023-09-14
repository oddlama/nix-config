{pkgs, ...}: {
  home.packages = with pkgs; [
    prismlauncher
  ];

  home.persistence."/persist".directories = [
    ".local/share/PrismLauncher"
  ];
}
