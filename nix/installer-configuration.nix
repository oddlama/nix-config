{pkgs, ...}: {
  system.stateVersion = "23.11";
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  console.keyMap = "de-latin1-nodeadkeys";

  boot.loader.systemd-boot.enable = true;

  users.users.root = {
    password = "nixos";
    openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5Uq+CDy5Pmt3If5M6d8K/Q7HArU6sZ7sgoj3T521Wm"];
  };

  environment = {
    variables.EDITOR = "nvim";
    systemPackages = with pkgs; [
      neovim
      git
      tmux
      parted
      ripgrep
      fzf
      wget
      curl
    ];

    etc.issue.text = ''
      \d  \t
      This is \e{cyan}\n\e{reset} [\e{lightblue}\l\e{reset}] (\s \m \r)
      \e{halfbright}\4\e{reset} \e{halfbright}\6\e{reset}
    '';
  };
}
