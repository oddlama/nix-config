{pkgs, ...}: {
  home.packages = with pkgs; [
    prismlauncher
  ];

  home.persistence."/state".directories = [
    ".local/share/PrismLauncher"
  ];
}
