## Structure

If you are interested in parts of my configuration, you probably want to examine the contents of `users/`, `config/`, `modules/` and `hosts/`.
Make sure to utilize the github search if you know what you need!

- `config/` contains common configuration that I use on all of my host
  and which is applied by default.
  - `config/optional/` contains optional configuration that is only needed for some hosts,
  and which should be included explicitly by hosts that require it.

- `hosts/<hostname>` contains the top-level configuration for `<hostname>`.
  Follow the imports from there to see what it entails.

  By convention I place secrets related to this host in the `secrets/` subfolder, but any host
  could technically use them. Especialy important files in this folder are:
  - `host.pub` This host's public key (retrieved after initial setup). Used to rekey secrets so the host can access them at runtime.
  - `local.nix.age` Repository-wide local secrets. Decrypted on import, see `modules/secrets.nix` for more information.

  Some hosts define guests that run as containerized or virtualized guests. Their configuration is usually just a single file
  stored in `guests/<name>.nix`. Their secrets are usually stored in a subfolder of the host's secrets folder.

- `modules/` contains modularized configuration. If you are interested in reusable parts of
  my configuration, this is probably the folder you are looking for. These will be regular
  reusable modules like those you would find in `nixpkgs/nixos/modules`.

  Some of these simplify the option interface of existing options, others add new funtionality
  to existing modules.

- `flake/` flake-parts modules and flake plumbing
  - `hosts.nix` Turns every directory in `hosts/` into a `nixosConfigurations` (and `nixosConfigurationsMinimal`) entry, and collects all hosts and their guests into `nodes`.
  - `pkgs.nix` Instantiates nixpkgs with the overlays from `pkgs/` (plus a CUDA-enabled `pkgsCuda`).
  - `devshell.nix` Devshell with formatting, pre-commit hooks and the `build`/`deploy` helpers.
  - `agenix-rekey.nix` Master identities and agenix-rekey setup.
  - `iso.nix` and `installer-configuration.nix` Our modified installer image (sets up ssh, ...). The `install-system` command itself is defined in `config/installer.nix`.
  - `extra-builtins.nix` and `rage-decrypt-and-cache.sh` Decrypt repository-wide secrets at evaluation time via `builtins.exec`, caching the output in `/var/tmp/nix-import-encrypted`.

- `pkgs/` Custom packages and scripts

- `secrets/` Global secrets and age identities
  - `global.nix.age` Repository-wide global secrets. Will be merged with regular globals, structure is defined by `modules/globals.nix`.
  - `backup.pub` Backup age-identity in case I ever lose my YubiKey or it breaks.
  - `yk1-nix-rage.pub` Master YubiKey split-identity. Used as a key-grab.

- `users/` User account configuration mostly via home-manager.
  This is the place to look for my dotfiles.
