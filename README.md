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
    - `[microvms/]` configuration for microvms. This is optional even for existing microvms, since they can also be defined in-place.
    - `secrets/` Local secrets for this host. Still theoretically accessible by other hosts, but owned by this one.
      - `local.nix.age` Repository-wide local secrets. Decrypted on import via `builtins.extraBuiltins.rageImportEncrypted`.
      - `[host.pub]` This host's public key. Used for agenix rekeying if it exists.
    - `default.nix` The actual system definition. Follow the imports from there to see what it entails.
    - `fs.nix` Filesystem setup.
    - `net.nix` Networking setup.
  - `nom/` - My laptop and main development machine
  - `ward/` - ODROID H3, energy efficient SBC. Used as a firewall betwenn my ISP and internal home network. Hosts some lightweight services using full KVM virtual machines.
  - `envoy/` - Hetzner Cloud server. Primarily used as my mailserver and VPN provider.
  - `zackbiene/` - ODROID N2+. Hosts IoT and Home Automation stuff and fully isolates that stuff from my internal network.
  - not yet ready to be publicized: my main development machine, the powerful home server, some services ... (still in transition from gentoo :/)
- `modules/` additional NixOS modules that are not yet upstreamed, or specific to this setup.
  - `interface-naming.nix` Provides an option to rename interfaces based on their MAC address
  - `microvms.nix` Used to define microvms including all of the boilerplate setup (networking, shares, local wireguard)
  - `repo.nix` Provides options to define and access repository-wide secrets
  - `wireguard.nix` A meta module that allows defining wireguard networks that automatically collects network participants across nodes
- `nix/` library functions and plumbing
  - `apps/` Additional runnable actions for this flake
    - `default.nix` Collects all apps and generates a definition for a specified system
    - `draw-graph.nix` (**WIP:** infrastructure graph renderer)
    - `format-secrets.nix` Runs the code formatter on the secret .nix files
    - `generate-initrd-keys.nix` Generates initrd hostkeys for each host if they don't exist yet (for setup)
    - `generate-wireguard-keys.nix` Generates wireguard keys for each server-and-peer pair
    - `show-wireguard-qr.nix` Generates a QR code for external wireguard participants
  - `checks.nix` pre-commit-hooks for this repository
  - `colmena.nix` Setup for distributed deployment using colmena (actually defines all NixOS hosts)
  - `dev-shell.nix` Environment setup for `nix develop` for using this flake
  - `extra-builtins.nix` Extra builtins via nix-plugins to support transparent repository-wide secrets
  - `generate-installer.nix` Helper functions to generate a iso image for any host for simple deployment from scratch. The iso will contain an executable `install-system` that will do a full install including partitioning.
  - `generate-node.nix` Helper function that outputs everything that is necessary to define a new node in a predictable format. Used to define colmena nodes and microvms.
  - `lib.nix` Commonly used functionality or helpers that weren't available in the standard library
  - `rage-decrypt-and-cache.sh` Auxiliary script for repository-wide secrets that decrypts a file and caches the output in /tmp
- `secrets/` Global secrets and age identities
  - `global.nix.age` Repository-wide global secrets. Available on nodes via the repo module as `config.repo.secrets.global`.
  - `backup.pub` Backup age-identity in case I ever lose my YubiKey or it breaks.
  - `yk1-nix-rage.pub` Master YubiKey split-identity. Used as a key-grab.
- `pkgs/` Custom packages and scripts
- `users/` User account configuration via home-manager. Imported by each host separately.

## How-To

#### Add new machine

... incomplete.

- add <name> to `hosts` in `flake.nix`
- create hosts/<name>
- fill net.nix
- fill fs.nix (you need to know the device by-id paths in advance for formatting to work!)
- generate-initrd-keys
- generate-wireguard-keys

#### Initial deploy

- Create a iso disk image for the system with `nix build --print-out-paths --no-link .#installer-image-<host>`
- dd the resulting image to a stick and boot from it on the target
- (Optional) ssh into the target (keys are already set up)
- Run `install-system` and reboot
- Retrieve the new host identity by using `ssh-keyscan <host/ip> | grep -o 'ed25519.*' > host/<host>/secrets/host.pub`
- (If the host has microvms, also retrieve their identities!)
- Rekey the secrets for the new identity `nix run .#rekey`
- Deploy again remotely via colmena

#### Remote encrypted unlock

If a host uses encrypted root together with the `common/initrd-ssh.nix` module,
it can be unlocked remotely by connecting via ssh on port 4 and executing `systemd-tty-ask-password-agent`.

#### Show QR for external wireguard client

nix run show-wireguard-qr
then select the host in the fzf menu

#### New secret

...

## Stuff

- Secrets can be created/edited by running `nix run .#edit-secret some/secret.age`
- Secrets can be rekeyed by running `nix run .#rekey` (you will also be prompted to do so in an error message if neccessary)

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

Generate self-signed cert, e.g. for kanidm internal communication to proxy:

```bash
openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -keyout selfcert.key -out selfcert.crt -subj \
  "/CN=example.com" -addext "subjectAltName=DNS:example.com,DNS:sub1.example.com,DNS:sub2.example.com,IP:10.0.0.1"
```
