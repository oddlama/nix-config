## Structure

If you are interested in parts of my configuration, you probably want to examine the contents of `users/`, `modules/` and `hosts/`.
Make sure to utilize the github search if you know what you need!

- `apps/` Additional runnable actions for flake maintenance, like showing wireguard QR codes.

- `hosts/<hostname>` contains the top-level configuration for `<hostname>`.
  Follow the imports from there to see what it entails.

  By convention I place secrets related to this host in the `secrets/` subfolder, but any host
  could technically use them. Especialy important files in this folder are:
  - `host.pub` This host's public key (retrieved after initial setup). Used to rekey secrets so the host can access them at runtime.
  - `local.nix.age` Repository-wide local secrets. Decrypted on import, see `modules/repo/secrets.nix` for more information.

  Some hosts define microvms that run as virtualized guests. Their configuration is usually just a single file
  stored in `microvms/<vm>.nix`. Their secrets are usually stored in a subfolder of the host's secrets.

- `lib/` contains extra library functions that are needed throughout the config.

- `modules/` contains modularized configuration. If you are interested in reusable parts of
  my configuration, this is probably the folder you are looking for. Unless stated otherwise,
  all of these will be regular reusable modules like those you would find in `nixpkgs/nixos/modules`,
  and the tree of all relevant modules is included via `modules/default.nix`.
  - `modules/config/` contains configuration that is I use across all my host and is applied by default.
    These just add configuration unconditionally and don't expose any further options.
  - `modules/optional/` contains configuration that is only needed sometimes, and which should
    be included explicitly by hosts that require it.
  - `modules/meta/` contains meta-modules that simplify the option interface of existing options.
    I use this for stuff that I don't need on all my hosts and that may require different settings
    for each host while sharing a common basis.
    Some of these are "meta" in the sense that they depend on their own definitions on multiple hosts (wireguard).
    These are probably as opinionated as stuff in `modules/config/` but may be a little more general.
    The `wireguard` module would even be a candidate for extraction to a separate flake, together with the related apps.
  - `modules/*/` regular modules related to <xyz>, similar structure as in `nixpkgs/nixos/modules`

- `nix/` library functions and flake plumbing
  - `checks.nix` pre-commit-hooks for this repository
  - `colmena.nix` Setup for distributed deployment using colmena (actually defines all NixOS hosts)
  - `dev-shell.nix` Environment setup for `nix develop` for using this flake
  - `extra-builtins.nix` Extra builtins via nix-plugins to support transparent repository-wide secrets
  - `generate-installer.nix` Helper functions to generate a iso image for any host for simple deployment from scratch. The iso will contain an executable `install-system` that will do a full install including partitioning.
  - `generate-node.nix` Helper function that outputs everything that is necessary to define a new node in a predictable format. Used to define colmena nodes and microvms.
  - `lib.nix` Commonly used functionality or helpers that weren't available in the standard library
  - `rage-decrypt-and-cache.sh` Auxiliary script for repository-wide secrets that decrypts a file and caches the output in /tmp

- `pkgs/` Custom packages and scripts

- `secrets/` Global secrets and age identities
  - `global.nix.age` Repository-wide global secrets. Available on nodes via the repo module as `config.repo.secrets.global`.
  - `backup.pub` Backup age-identity in case I ever lose my YubiKey or it breaks.
  - `yk1-nix-rage.pub` Master YubiKey split-identity. Used as a key-grab.

- `users/` User account configuration mostly via home-manager.
  This is the place to look for my dotfiles.
