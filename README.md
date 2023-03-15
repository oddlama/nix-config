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
