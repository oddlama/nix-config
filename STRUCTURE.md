## Structure

If you are interested in parts of my configuration, you probably want to examine the contents of `users/`, `modules/` and `hosts/`.
Make sure to utilize the github search if you know what you need!

- `hosts/<hostname>` contains the top-level configuration for `<hostname>`.
  Follow the imports from there to see what it entails.

  By convention I place secrets related to this host in the `secrets/` subfolder, but any host
  could technically use them. Especialy important files in this folder are:
  - `host.pub` This host's public key (retrieved after initial setup). Used to rekey secrets so the host can access them at runtime.
  - `local.nix.age` Repository-wide local secrets. Decrypted on import, see `modules/repo/secrets.nix` for more information.

  Some hosts define guests that run as containerized or virtualized guests. Their configuration is usually just a single file
  stored in `guests/<name>.nix`. Their secrets are usually stored in a subfolder of the host's secrets folder.

- `lib/` contains extra library functions that are needed throughout the config.

- `modules/` contains modularized configuration. If you are interested in reusable parts of
  my configuration, this is probably the folder you are looking for. Unless stated otherwise,
  all of these will be regular reusable modules like those you would find in `nixpkgs/nixos/modules`,
  and the tree of all relevant modules is included via `modules/default.nix`.
  - `modules/config/` contains configuration that is I use across all my host and is applied by default.
    These just add configuration unconditionally and don't expose any further options.
  - `modules/optional/` contains configuration that is only needed sometimes, and which should
    be included explicitly by hosts that require it.
  - `modules/*` contains regular modules and meta-modules that simplify the option interface of existing options.
    I use this for stuff that I don't need on all my hosts and that may require different settings
    for each host while sharing a common basis.
    Some of these are "meta" in the sense that they depend on their own definitions on multiple hosts (wireguard).
    These are probably as opinionated as stuff in `modules/config/` but may be a little more general.

- `nix/` library functions and flake plumbing
  - `generate-installer-package.nix` Helper package that that will be available in our iso images. This provides the `install-system` command that will do a full install including partitioning.
  - `hosts.nix` Loads all host declarations from host.toml and defines the actual hosts in nixosConfigurations.
  - `installer-configuration.nix` Our modified ISO installer image config (sets up ssh, contains the installer package, ...)
  - `rage-decrypt-and-cache.sh` Auxiliary script for repository-wide secrets that decrypts a file and caches the output in /tmp

- `pkgs/` Custom packages and scripts

- `secrets/` Global secrets and age identities
  - `global.nix.age` Repository-wide global secrets. Available on nodes via the repo module as `config.repo.secrets.global`.
  - `backup.pub` Backup age-identity in case I ever lose my YubiKey or it breaks.
  - `yk1-nix-rage.pub` Master YubiKey split-identity. Used as a key-grab.

- `users/` User account configuration mostly via home-manager.
  This is the place to look for my dotfiles.
