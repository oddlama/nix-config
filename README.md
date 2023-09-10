# About

This is my personal nix config. It's still in the making, but this is what I got so far:

- Log and system monitoring via loki, telegraf, influxdb, promtail and grafana
- Single-Sign-On for all services using oauth2 via kanidm
- Automatic wireguard mesh generation
- Full disk encryption using [disko](https://github.com/nix-community/disko), remotely unlockable via ssh
- Zoned nftables firewall via [nixos-nftables-firewall](https://github.com/thelegy/nixos-nftables-firewall)
- Service isolation using [microvms](https://github.com/astro/microvm.nix) instead of containers
- Secret rekeying, generation and bootstrapping using [agenix-rekey](https://github.com/oddlama/agenix-rekey)
- Support for repository-wide secrets at evaluation time (hides PII like MACs)

## Hosts

|  | Name | Type | Purpose
---|---|---|---
💻 | nom | Gigabyte AERO 15-W8 (i7-8750H) | My laptop and my main portable development machine <sub>Framework when?</sub>
🖥️ | kroma | PC (AMD Ryzen 9 5900X) | Main workstation and development machine
🖥️ | ward | ODROID H3 | Energy efficient SBC for my home firewall and some lightweight services using microvms.
🥔 | zackbiene | ODROID N2+ | ARM SBC for home automation, isolating the sketchy stuff from my main network
☁️  | envoy | Hetzner Cloud server | Mailserver
☁️  | sentinel | Hetzner Cloud server | Proxies and protects my local services

<!-- 🖥️ home server -->

<sub>
not yet nixified: my main development machine, the powerful home server, and some services (still in transition from gentoo :/)
</sub>

## Programs

|   |   |
|---|---|
**Shell** | [nushell](https://github.com/nushell/nushell)
**Terminal** | [kitty](https://github.com/kovidgoyal/kitty)
**Editor** | [neovim](https://github.com/neovim/neovim)
**WM** | [sway](https://github.com/swaywm/sway)

## Structure

If you are interested in parts of my configuration,
you probably want to examine the contents of `users/`, `modules/` and `hosts/`.
The full structure of this flake is described in [STRUCTURE.md](./STRUCTURE.md),
but here's a quick breakdown of the what you will find where.

|   |   |
|---|---|
`apps/` | runnable actions for flake maintenance
`hosts/<hostname>` | top-level configuration for `<hostname>`
`lib/` | library functions overlayed on top of `nixpkgs.lib`
`modules/config/` | global configuration for all hosts
`modules/optional/` | optional configuration included by hosts
`modules/meta/` | simplified setup for existing modules and cross-host config
`modules/*/` | classical reusable configuration modules
`nix/` | library functions and flake plumbing
`pkgs/` | Custom packages and scripts
`secrets/` | Global secrets and age identities
`users/` | User configuration and dotfiles

## How-To

#### Add new machine

... incomplete.

- Add <name> to `hosts` in `flake.nix`
- Create hosts/<name>
- Fill net.nix
- Fill fs.nix (you need to know the device by-id paths in advance for formatting to work!)
- Run generate-secrets

#### Initial deploy

- Create a bootable iso disk image with `nix build --print-out-paths --no-link .#images.<target-system>.live-iso`, dd it to a stick and boot
- (Alternative) Use an official NixOS live-iso and setup ssh manually
- Copy the installer from a local machine to the live system with `nix copy --to <target> .#packages.<target-system>.installer-package.<target>`

Afterwards:

- Run `install-system` in the live environment and reboot
- Retrieve the new host identity by using `ssh-keyscan <host/ip> | grep -o 'ssh-ed25519.*' > hosts/<host>/secrets/host.pub`
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
