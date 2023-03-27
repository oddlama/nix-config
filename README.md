# About

## Structure

- `hosts/`

  - `common/` shared configuration

    - `core/` configuration that is shared across all machines. (base setup, ssh, ...)

  - `<hostname>/`

	- `secrets/` Local secrets for this host. Still theoretically accessible by other hosts, but owned by this one.

	  - `secrets.nix.age` Repository-wide local secrets. Decrypted on import via `builtins.extraBuiltins.rageImportEncrypted`.
	  - `host.pub` This host's public key.Repository-wide local secrets. Decrypted on import via `builtins.extraBuiltins.rageImportEncrypted`.

  - `nom/`

- `modules/` additional NixOS modules that are not yet upstreamed.

- `nix/` library functions and plumbing

  - `apps.nix` Additional runnable actions for this flake (**WIP:** infrastructure graph renderer)
  - `checks.nix` pre-commit-hooks for this repository
  - `colmena.nix` Setup for distributed deployment using colmena (actually defines all NixOS hosts)
  - `dev-shell.nix` Environment setup for `nix develop` for using this flake
  - `extra-builtins.nix` Extra builtins via nix-plugins to support transparent repository-wide secrets
  - `home-manager.nix` Definition of home-manager only hosts (not used currently)
  - `hosts.nix` Wrapper that extracts all defined hosts from `hosts/`
  - `overlays/**` Local overlay packages. Subject for removal.
  - `overlay.nix` Overlay defintions
  - `overlay.nix` Overlay defintions
  - `rage-decrypt.sh` Auxiliary script for repository-wide secrets
  - `secrets.nix` Helper to access repository-wide secrets, used by colmena.nix

- `secrets/` Global secrets and age identities

  - `secrets.nix.age` Repository-wide global secrets. Decrypted on import via `builtins.extraBuiltins.rageImportEncrypted`.
  - `backup.pub` Backup age identity in case I lose my YubiKey
  - `yk1-nix-rage.pub` Master YubiKey split-identity

- `pkgs/` Custom packages and scripts

- `users/` User account configuration via home-manager. Imported by each host separately.

## Stuff

This is my personal nix config.

- Secrets can be created/edited by running `nix run .#edit-secret some/secret.age`
- Secrets can be rekeyed by running `nix run .#rekey` (you will be prompted to do so in an error message if neccessary)

To be able to decrypt the repository-wide secrets transparently on a host that
is _not_ managed by this config, you will need to <sub>(be me and)</sub> run
all commands using these extra parameters, or permanently add the following the system's `nix.conf`:

1. Get nix-plugins: `NIX_PLUGINS=$(nix build --print-out-paths --no-link nixpkgs#nix-plugins)`
2. Run all commands with `--option plugin-files "$NIX_PLUGINS"/lib/nix/plugins --option extra-builtins-file ./nix/extra-builtins.nix`
   or permantently

	```toml
	plugin-files = <copy path from $NIX_PLUGINS>/lib/nix/plugins
	extra-builtins-file = /path/to/nix-config/nix/extra-builtins.nix
	```

## Misc

Generate self-signed cert:

```bash
openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -keyout zackbiene-selfcert.key -out zackbiene-selfcert.crt -subj \
  "/CN=example.com" -addext "subjectAltName=DNS:example.com,DNS:sub1.example.com,DNS:sub2.example.com,IP:10.0.0.1"
```
