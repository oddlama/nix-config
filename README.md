# About

This is my personal nix config.

## Structure

- `hosts/` contains configuration for all hosts.
  - `common/` shared configuration. Hosts will include what they need from here.
    - `core/` configuration that is shared across _all_ machines. (base setup, ssh, ...)
    - `dev/` configuration for development machines
    - `graphical/` configuration for graphical setup
    - `hardware/` configuration for various hardware components
    - `<something>.nix` commonly required configuration for `<something>`
  - `<hostname>/` configuration for `<hostname>`
	- `secrets/` Local secrets for this host. Still theoretically accessible by other hosts, but owned by this one.
	  - `secrets.nix.age` Repository-wide local secrets. Decrypted on import via `builtins.extraBuiltins.rageImportEncrypted`.
	  - `host.pub` This host's public key. Used for agenix rekeying.
	- `default.nix` The actual system definition. Follow the imports from there to see what it entails.
	- `meta.nix` Determines the type and architecture of this system, and some other optional meta information. Used e.g. by `nix/colmena.nix` to know which hosts are real NixOS hosts, and which are VMs or some other type.
	- `fs.nix` Filesystem setup.
	- `net.nix` Networking setup.
  - `nom/` - My laptop and main development machine
  - `ward/` - ODROID H3, energy efficient SBC. Used as a firewall betwenn my ISP and internal home network. Hosts some lightweight services using full KVM virtual machines.
  - `envoy/` - Hetzner Cloud server. Primarily used as my mailserver and VPN provider.
  - `zackbiene/` - ODROID N2+. Hosts IoT and Home Automation stuff and fully isolates that from my internal network.
  - not yet ready for publicized: my main development machine, powerful home server, some services ... (still in transition from gentoo :/)
- `modules/` additional NixOS modules that are not yet upstreamed.
- `nix/` library functions and plumbing
  - `apps/` Additional runnable actions for this flake
    - `default.nix` Collects all apps and generates a definition for a specified system
    - `draw-graph.nix` (**WIP:** infrastructure graph renderer)
    - `format-secrets.nix` Runs the code formatter on the secret .nix files
    - `generate-initrd-keys.nix` Generates initrd hostkeys for each host if they don't exist yet (for setup)
    - `generate-wireguard-keys.nix` Generates wireguard keys for each server-and-peer pair
  - `checks.nix` pre-commit-hooks for this repository
  - `colmena.nix` Setup for distributed deployment using colmena (actually defines all NixOS hosts)
  - `dev-shell.nix` Environment setup for `nix develop` for using this flake
  - `extra-builtins.nix` Extra builtins via nix-plugins to support transparent repository-wide secrets
  - `hosts.nix` Wrapper that extracts all defined hosts from `hosts/`
  - `lib.nix` Commonly used functionality or helpers that weren't available in the standard library
  - `rage-decrypt.sh` Auxiliary script for repository-wide secrets
  - `secrets.nix` Helper to access repository-wide secrets, used by colmena.nix
- `secrets/` Global secrets and age identities
  - `secrets.nix.age` Repository-wide global secrets. Decrypted on import via `builtins.extraBuiltins.rageImportEncrypted`.
  - `backup.pub` Backup age-identity in case I ever lose my YubiKey or it breaks.
  - `yk1-nix-rage.pub` Master YubiKey split-identity. Used as a key-grab.
- `pkgs/` Custom packages and scripts
- `users/` User account configuration via home-manager. Imported by each host separately.

## How-To

#### Add and deploy new machine

...

- add hosts/<name>
- fill meta.nix
- fill net.nix
- todo: hostid (move to nodeSecrets)
- generate-initrd-keys
- generate-wireguard-keys

#### Show QR for external wireguard client

nix run show-wireguard-qr
then select the host in the fzf menu

#### New secret

...

## Stuff

- Secrets can be created/edited by running `nix run .#edit-secret some/secret.age`
- Secrets can be rekeyed by running `nix run .#rekey` (you will be prompted to do so in an error message if neccessary)

To be able to decrypt the repository-wide secrets transparently on a host that
is _not_ managed by this config, you will need to <sub>(be me and)</sub> run
all commands using these extra parameters, or permanently add the following the system's `nix.conf`:

1. Get nix-plugins: `NIX_PLUGINS=$(nix build --print-out-paths --no-link nixpkgs#nix-plugins)`
2. Run all commands with `--option plugin-files "$NIX_PLUGINS"/lib/nix/plugins --option extra-builtins-file ./nix/extra-builtins.nix`
   or permantently

	```ini
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
