[Hosts](#hosts) \| [Overview](#overview) \| [Structure](./STRUCTURE.md)

![preview](https://github.com/oddlama/nix-config/assets/31919558/139c94de-9ecd-4b36-ab5c-c654d9e38888)

## ❄️  My NixOS Configuration

This is my personal nix config which I use to maintain my whole infrastructure,
including my homelab, external servers and my development machines.

## Hosts

|  | Type | Name | Hardware | Purpose
---|---|---|---|---
💻 | Laptop | nom | Gigabyte AERO 15-W8 (i7-8750H) | My laptop and my main portable development machine <sub>Framework when?</sub>
🖥️ | Desktop | kroma | PC (AMD Ryzen 9 5900X) | Main workstation and development machine, also for some occasional gaming
🖥️ | Server | ward | ODROID H3 | Energy efficient SBC for my home firewall and some lightweight services using containers and microvms.
🖥️ | Server | sire | Threadripper 1950X | Home media server and data storage. Runs all services as microvms.
🖥️ | Server | sausebiene | Intel N100 | Home automation and IoT network isolation
🥔 | Server | zackbiene | ODROID N2+ | Decomissioned. Old home assistant board
☁️  | VPS | sentinel | Hetzner Cloud server | Proxies and protects my local services
☁️  | VPS | envoy | Hetzner Cloud server | Mailserver

## Overview

An overview over what you will find in this repository. I usually put a lot of
effort into all my configurations and try to go over every option in detail.
I've included the major components in the lists below.

#### Dotfiles

| ~~~~~~~~~~~~ | Program | Source | Description
---|---|---|---
🐚 Shell | ZSH & Starship | [Link](./users/config/shell) | ZSH configuration with FZF, starship prompt, sqlite history and histdb-skim for fancy <kbd>Ctrl</kbd><kbd>R</kbd>
🖥️ Terminal | Kitty | [Link](./users/myuser/graphical/kitty.nix) | Terminal configuration with nerdfonts and history <kbd>Ctrl</kbd><kbd>Shift</kbd><kbd>H</kbd> to view scrollback buffer in neovim
🪟 WM | hyprland & i3 | [Link](./users/myuser/graphical/hyprland.nix), [Link](./users/myuser/graphical/i3.nix) | Tiling window manager, heavily customized to my personal preferences
🔋 Bar | waybar | [Link](./users/myuser/graphical/waybar.nix) | Taskbar and status
🌐 Browser | Firefox | [Link](./users/myuser/graphical/firefox.nix) | Firefox with many privacy settings and betterfox
🖊️ Editor | Neovim | [Link](./users/myuser/neovim) | Extensive neovim configuration, made with nixvim
📜 Manpager | Neovim | [Link](./users/config/manpager.nix) | Isolated neovim as manpager via nixvim
📷 Screenshots | Custom based on grimblast | [Link](./pkgs/scripts) | Custom scripts utilizing grimblast for [QR code detection](./pkgs/scripts/screenshot-area-scan-qr.nix) and [OCR / satty editing](./pkgs/scripts/screenshot-area.nix)
🗨️ Notifications | SwayNotificationCenter | [Link](./users/myuser/graphical/swaync.nix) | Notification center with customized color scheme
🎮 Gaming | Steam & Bottles | [Link](./users/myuser/graphical/games) | Setup for gaming
📫 Mail | Thunderbird | [Link](./users/myuser/graphical/thunderbird.nix) | Your regular thunderbird setup

#### Services

| ~~~~~~~~~~~~ | Service | Source | Description
---|---|---|---
💸 Budgeting | Firefly III \& Firefly Pico | [Link](./hosts/ward/guests/firefly.nix) | Budgeting application to track income and expenses
🛡️ Adblock | AdGuard Home | [Link](./hosts/ward/guests/adguardhome.nix) | DNS level adblocker
🔒 SSO | Kanidm | [Link](./hosts/ward/guests/kanidm.nix) | Identity provider for Single-Sign-On on my hosted services, with provisioning.
🐙 Git | Forgejo | [Link](./hosts/ward/guests/forgejo.nix) | Forgejo with SSO
🔑 Passwords | Vaultwarden | [Link](./hosts/ward/guests/vaultwarden.nix) | Self-hosted password manager
📷 Photos | Immich | [Link](./hosts/sire/guests/immich.nix) | Self-hosted photo and video backup solution
📄 Documents | Paperless | [Link](./hosts/sire/guests/paperless.nix) | Document management system. With per-user Samba share integration (consume & archive)
🗓️ CalDAV/CardDAV | Radicale | [Link](./hosts/ward/guests/radicale.nix) | Contacts, Calender and Tasks synchronization
📁 NAS | Samba | [Link](./hosts/sire/guests/samba.nix) | Network attached storage. Cross-integration with paperless
🌐 VPN | Firezone | [Link](./hosts/ward/guests/firezone.nix) | Internal network gateway and wireguard VPN server with dynamic peer configuration and SSO authentication.
🏠 Home Automation | Home Assistant | [Link](./hosts/zackbiene/home-assistant.nix) | Automation with Home Assistant and many related services
📧 Mailserver | Stalwart | [Link](./hosts/envoy/stalwart-mail.nix) | Modern mail server setup with custom self-service alias management including Bitwarden integration
🧱 Minecraft | PaperMC | [Link](./hosts/sire/guests/minecraft.nix) | Minecraft game server. Autostart on connect, systemd service with background console, automatic backups
🐒 Local LLM | Ollama & open-webui | [Link](./hosts/sire/guests/ai.nix) | Local LLM and AI Chat
📊 Dashboard | Grafana | [Link](./hosts/sire/guests/grafana.nix) | Logs and metrics dashboard and alerting
📔 Logs DB | Loki | [Link](./hosts/sire/guests/loki.nix) | Central log aggregation service
📔 Logs Agent | Promtail | [Link](./modules/promtail.nix) | Log shipping agent
📚 TSDB | Influxdb2 | [Link](./hosts/sire/guests/influxdb.nix) | Time series database for storing host metrics
⏱️  Metrics | Telegraf | [Link](./modules/telegraf.nix) | Per-host collection of metrics

<!--
- home assistant & subcomponents
- scrutiny
- ollama
- open-webui
-->

#### General & Miscellaneous

(WIP)

| ~~~~~~~~~~~~ | Source | Description
---|---|---
🗑️ Impermanence | [Link](./config/impermanence.nix) | Only persist what is necessary. ZFS rollback on boot. Most configuration is will be next to the respective service / program configuration.

- reverse proxy with wireguard tunnel
- restic
- static wireguard mesh
- unified guests interface for microvms and containers with ZFS integration
- zoned nftables
- Secret rekeying, generation and bootstrapping using [agenix-rekey](https://github.com/oddlama/agenix-rekey)
- Remote-unlockable full disk encryption using ZFS on LUKS <!-- with automatic snapshots and backups -->
- Automatic disk partitioning via [disko](https://github.com/nix-community/disko)
- Support for repository-wide secrets at evaluation time (hides PII like MACs)

## Structure

If you are interested in parts of my configuration,
you probably want to examine the contents of `users/`, `config/`, `modules/` and `hosts/`.
Also, a lot of interesting modules have been moved to [nixos-extra-modules](https://github.com/oddlama/nixos-extra-modules), a separate repository specifically for reusable stuff.
The full structure of this flake is described in [STRUCTURE.md](./STRUCTURE.md),
but here's a quick breakdown of the what you will find where.

|   |   |
|---|---|
`config/` | global configuration for all hosts
`config/optional/` | optional configuration included by hosts
`hosts/<hostname>` | top-level configuration for `<hostname>`
`modules/` | classical reusable configuration modules
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
- Copy the installer from a local machine to the live system with `nix copy --to <target> .#nixosConfigurationsMinimal.config.system.build.installFromLive`

Afterwards:

- Run `install-system` in the live environment, export your zfs pools and reboot
- Retrieve the new host identity by using `ssh-keyscan <host/ip> | grep -o 'ssh-ed25519.*' > hosts/<host>/secrets/host.pub`
- (If the host has guests, also retrieve their identities!)
- Rekey the secrets for the new identity `nix run .#rekey`
- Deploy again

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
