[Hosts](#hosts) \| [Programs](#programs--services) \| [Structure](./STRUCTURE.md)

![2024-01-04T21:24:51+01:00-fullscreen](https://github.com/oddlama/nix-config/assets/31919558/f473b473-0715-4323-89f2-5a79140ba54c)

## ❄️  My NixOS Configuration

This is my personal nix config. It's still in the making, but this is what I got so far:

- Secret rekeying, generation and bootstrapping using [agenix-rekey](https://github.com/oddlama/agenix-rekey)
- Remote-unlockable full disk encryption using ZFS on LUKS <!-- with automatic snapshots and backups -->
- Automatic disk partitioning via [disko](https://github.com/nix-community/disko)
- Support for repository-wide secrets at evaluation time (hides PII like MACs)
- Automatic static wireguard mesh generation <!-- plus netbird for dynamic meshing -->
- Opt-in persistence with [impermanence](https://github.com/nix-community/impermanence)
<!-- - Secure boot using [lanzaboote](https://github.com/nix-community/lanzaboote) -->

<!--
Desktop machines:

- [Secondary neovim instance](./users/modules/config/manpager/default.nix) as a better manpager
- System-wide theme using [stylix](https://github.com/danth/stylix)
-->

Server related stuff:

- Log and system monitoring through [grafana](https://github.com/grafana/grafana) using
  - [influxdb2](https://github.com/influxdata/influxdb) and [telegraf](https://github.com/influxdata/telegraf) for metrics
  - [loki](https://github.com/grafana/loki) and [promtail](https://grafana.com/docs/loki/latest/clients/promtail/) for logs
- Single-Sign-On for all services using oauth2 via [kanidm](https://github.com/kanidm/kanidm)
- Zoned nftables firewall via [nixos-nftables-firewall](https://github.com/thelegy/nixos-nftables-firewall)
- Service isolation using [microvms](https://github.com/astro/microvm.nix) and nixos-containers

## Hosts

|  | Type | Name | Hardware | Purpose
---|---|---|---|---
💻 | Laptop | nom | Gigabyte AERO 15-W8 (i7-8750H) | My laptop and my main portable development machine <sub>Framework when?</sub>
🖥️ | Desktop | kroma | PC (AMD Ryzen 9 5900X) | Main workstation and development machine, also for some occasional gaming
🖥️ | Server | ward | ODROID H3 | Energy efficient SBC for my home firewall and some lightweight services using containers and microvms.
🖥️ | Server | sire | Threadripper 1950X | Home media server and data storage. Runs all services as microvms.
🥔 | Server | zackbiene | ODROID N2+ | ARM SBC for home automation, isolating the sketchy stuff from my main network
☁️  | VPS | sentinel | Hetzner Cloud server | Proxies and protects my local services
☁️  | VPS | envoy | Hetzner Cloud server | Mailserver (WIP, still on gentoo)

## Programs & Services

#### Desktop Programs

|   |   |
|---|---|
**Shell** | zsh <!--& [nushell](https://github.com/nushell/nushell)--> with [starship](https://github.com/starship/starship), fzf plugins and sqlite history
**Terminal** | [kitty](https://github.com/kovidgoyal/kitty)
**Editor** | [neovim](https://github.com/neovim/neovim) via [nixvim](https://github.com/nix-community/nixvim)
**WM** | [sway](https://github.com/swaywm/sway) & [i3](https://github.com/i3/i3) (still need X11 for gaming)
**Browser** | [Firefox](https://www.mozilla.org/en-US/firefox/new/)
**Notifications** | [wired-notify](https://github.com/Toqozz/wired-notify)
**Screenshots** | [Flameshot](https://github.com/flameshot-org/flameshot) with custom [QR code detection](./pkgs/scripts/screenshot-area-scan-qr.nix) and [OCR to clipboard](./pkgs/scripts/screenshot-area.nix)
**Gaming** | [Steam](https://store.steampowered.com/) and [Bottles](https://github.com/bottlesdevs/Bottles)

#### Services

|   |   |
|---|---|
**Git** | Forgejo
**SSO** | Kanidm
**Logs** | Loki
**Time Series DB** | Influxdb
**Monitoring** | Grafana
**DNS AdBlock** | AdGuard Home
**Passwords** | Vaultwarden
**Photos** | Immich
**Documents** | Paperless

## Structure

If you are interested in parts of my configuration,
you probably want to examine the contents of `users/`, `modules/` and `hosts/`.
The full structure of this flake is described in [STRUCTURE.md](./STRUCTURE.md),
but here's a quick breakdown of the what you will find where.

|   |   |
|---|---|
`hosts/<hostname>` | top-level configuration for `<hostname>`
`lib/` | library functions overlayed on top of `nixpkgs.lib`
`modules/config/` | global configuration for all hosts
`modules/optional/` | optional configuration included by hosts
`modules/*` | classical reusable configuration modules
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
- Fill fs.nix (you need to know the device /dev/by-id paths in advance for partitioning to work!)
- Run `agenix generate` and `agenix rekey` (create's dummy secrets for initial deploy)

#### Initial deploy

- Create a bootable iso disk image with `nix build --print-out-paths --no-link .#images.<target-system>.live-iso`, dd it to a stick and boot
- (Alternative) Use an official NixOS live-iso and setup ssh manually
- Copy the installer from a local machine to the live system with `nix copy --to <target> .#packages.<target-system>.installer-package.<target>`

Afterwards:

- Run `install-system` in the live environment, export your zfs pools and reboot
- Retrieve the new host identity by using `ssh-keyscan <host/ip> | grep -o 'ssh-ed25519.*' > hosts/<host>/secrets/host.pub`
- (If the host has guests, also retrieve their identities!)
- Rekey the secrets for the new identity `nix run .#rekey`
- Deploy again

#### Remote encrypted unlock

If a host uses encrypted root together with the `common/initrd-ssh.nix` module,
it can be unlocked remotely by connecting via ssh on port 4 and executing `systemd-tty-ask-password-agent`.

#### Show QR for external wireguard client

nix run show-wireguard-qr
then select the host in the fzf menu

#### New secret

...

## Stuff

- Generate, edit and rekey secrets with `agenix <generate|edit|rekey>`

To be able to decrypt the repository-wide secrets (files that contain my PII and are thus hidden from public view),
you will need to <sub>(be me and)</sub> add nix-plugins and point it to `./nix/extra-builtins.nix`.
The devshell will do this for you automatically. If this doesn't work for any reason, this can also be done manually:

1. Get nix-plugins: `NIX_PLUGINS=$(nix build --print-out-paths --no-link nixpkgs#nix-plugins)`
2. Run all commands with `--option plugin-files "$NIX_PLUGINS"/lib/nix/plugins --option extra-builtins-file ./nix/extra-builtins.nix`

## Misc

Generate self-signed cert, e.g. for kanidm internal communication to proxy:

```bash
openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -keyout selfcert.key -out selfcert.crt -subj \
  "/CN=example.com" -addext "subjectAltName=DNS:example.com,DNS:sub1.example.com,DNS:sub2.example.com,IP:10.0.0.1"
```
