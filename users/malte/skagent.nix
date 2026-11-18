{
  inputs,
  lib,
  ...
}:
let
  socket = "skagent.sock";
in
{
  imports = [ inputs.skagent.homeModules.default ];

  services.skagent = {
    enable = true;
    # skagent's own pinentry (skagent-pinentry): PIN, touch and result in one
    # layer-shell window on niri, instead of pinentry + touch notification
    popup.enable = true;
  };

  # gpg-agent's SSH support (gpg.nix) also defines sshAuthSock, which conflicts
  # with skagent. Force skagent's values so SSH_AUTH_SOCK points at it by default.
  # gpg-agent's ssh socket keeps running as a fallback for hosts that only know
  # the gpg key: SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket) ssh …
  # Mirrors nix/home-manager.nix in skagent. Drop this together with
  # services.gpg-agent.enableSshSupport.
  sshAuthSock = lib.mkForce {
    enable = true;
    initialization = {
      bash = ''export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/${socket}"'';
      fish = ''set -x SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/${socket}"'';
      nushell = ''$env.SSH_AUTH_SOCK = $"($env.XDG_RUNTIME_DIR)/${socket}"'';
    };
    systemd.socketProviderUnit = "skagent.socket";
  };
}
