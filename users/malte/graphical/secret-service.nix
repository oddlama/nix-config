{
  config,
  lib,
  nixosConfig,
  pkgs,
  ...
}:
let
  storeDir = "${config.xdg.dataHome}/password-store";
in
{
  # Secret service (org.freedesktop.secrets, used by libsecret/secret-tool) backed by
  # a pass store. Every secret is GPG-encrypted to the yubikey, so reading one needs
  # the key plugged in and its PIN (cached by gpg-agent), instead of a keyring password.
  programs.password-store = {
    enable = true;
    settings.PASSWORD_STORE_DIR = storeDir;
  };
  services.pass-secret-service = {
    enable = true;
    storePath = storeDir;
  };
  # niri-flake's home module enables gnome-keyring, but only one secret service may run
  services.gnome-keyring.enable = lib.mkForce false;

  # Initialize the store for the yubikey's GPG key. The fingerprint is taken from the
  # encrypted public key at activation time so it doesn't end up in the repo.
  home.activation.initPasswordStore = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [[ ! -e ${lib.escapeShellArg storeDir}/.gpg-id ]]; then
      fpr=$(${lib.getExe config.programs.gpg.package} --show-keys --with-colons \
        ${lib.escapeShellArg nixosConfig.age.secrets.my-gpg-pubkey-yubikey.path} \
        | ${lib.getExe pkgs.gawk} -F: '/^fpr/ { print $10; exit }')
      run mkdir -p ${lib.escapeShellArg storeDir}
      if [[ -z "''${DRY_RUN:-}" ]]; then
        echo "$fpr" > ${lib.escapeShellArg storeDir}/.gpg-id
      fi
    fi
  '';

  home.persistence."/persist".directories = [
    ".local/share/password-store"
  ];
}
