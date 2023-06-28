# About

This is my personal nix config.

## Hosts

  TODO make a table.
  - `nom/` - My laptop and main development machine
  - `ward/` - ODROID H3, energy efficient SBC. Used as a firewall betwenn my ISP and internal home network. Hosts some lightweight services using full KVM virtual machines.
  - `envoy/` - Hetzner Cloud server. Primarily used as my mailserver and VPN provider.
  - `sentinel/` - Hetzner Cloud server. Primarily used as a http proxy
  - `zackbiene/` - ODROID N2+. Hosts IoT and Home Automation stuff and fully isolates that stuff from my internal network.
  - not yet ready to be publicized: my main development machine, the powerful home server, some services ... (still in transition from gentoo :/)

## Structure

- `apps/` Additional runnable actions for flake maintenance, like showing wireguard QR codes.

- `hosts/<hostname>` contains the top-level configuration for `<hostname>`.
  Follow the imports from there to see what it entails.

  By convention I place secrets related to this host in the `secrets/` subfolder, but any host
  could technically use them. Especialy important files in this folder are:

  - `host.pub` This host's public key (retrieved after initial setup). Used to rekey secrets so the host can access them at runtime.
  - `local.nix.age` Repository-wide local secrets. Decrypted on import, see `modules/repo/secrets.nix` for more information.

  Some hosts define microvms that run as their guests. These are typically stored
  in `microvms/<vm>` and have the same layout as a regular host.

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

  - `modules/<xyz>/` regular modules related to <xyz>, similar structure as in `nixpkgs/nixos/modules`

- `pkgs/` Custom packages and scripts

- `secrets/` Global secrets and age identities
  - `global.nix.age` Repository-wide global secrets. Available on nodes via the repo module as `config.repo.secrets.global`.
  - `backup.pub` Backup age-identity in case I ever lose my YubiKey or it breaks.
  - `yk1-nix-rage.pub` Master YubiKey split-identity. Used as a key-grab.

- `users/` User account configuration mostly via home-manager.
  This is the place to look for my dotfiles.

- `nix/` library functions and flake plumbing
  - `checks.nix` pre-commit-hooks for this repository
  - `colmena.nix` Setup for distributed deployment using colmena (actually defines all NixOS hosts)
  - `dev-shell.nix` Environment setup for `nix develop` for using this flake
  - `extra-builtins.nix` Extra builtins via nix-plugins to support transparent repository-wide secrets
  - `generate-installer.nix` Helper functions to generate a iso image for any host for simple deployment from scratch. The iso will contain an executable `install-system` that will do a full install including partitioning.
  - `generate-node.nix` Helper function that outputs everything that is necessary to define a new node in a predictable format. Used to define colmena nodes and microvms.
  - `lib.nix` Commonly used functionality or helpers that weren't available in the standard library
  - `rage-decrypt-and-cache.sh` Auxiliary script for repository-wide secrets that decrypts a file and caches the output in /tmp

## How-To

#### Add new machine

... incomplete.

- add <name> to `hosts` in `flake.nix`
- create hosts/<name>
- fill net.nix
- fill fs.nix (you need to know the device by-id paths in advance for formatting to work!)
- run generate-secrets

#### Initial deploy

A. Fresh pre-made installer ISO

- Create a iso disk image for the system with `nix build --print-out-paths --no-link .#installer-image-<host>`
- dd the resulting image to a stick and boot from it on the target
- (Optional) ssh into the target (keys are already set up)

B. Reusing any nixos-live iso

- Boot from live-iso and setup ssh access by writing your key to `/root/.ssh/authorized_keys`
- Copy installer package with `nix copy --to <target> .#installer-package-<host>`

Afterwards:

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










```bash
# Recover admin account (server must not be running)
systemctl stop kanidm
kanidmd recover-account -c server.toml admin
> AhNeQgKkwwEHZ85dxj1GPjx58vWsBU8QsvKSyYwUL7bz57bp
systemctl start kanidm
# Login with recovered root account
kanidm login --name admin
# Generate new credentials for idm_admin account
kanidm service-account credential generate -D admin idm_admin
> Yk0W24SQGzkLp97DNxxExCcryDLvA7Q2dR0A7ZuaVQevLR6B
# Generate new oauth2 app for grafana
kanidm group create grafana-access
kanidm group create grafana-server-admins
kanidm group create grafana-admins
kanidm group create grafana-editors
kanidm system oauth2 create grafana "Grafana" https://grafana.${personalDomain}
kanidm system oauth2 update-scope-map grafana grafana-access openid email profile
kanidm system oauth2 update-sup-scope-map grafana grafana-server-admins server_admin
kanidm system oauth2 update-sup-scope-map grafana grafana-admins admin
kanidm system oauth2 update-sup-scope-map grafana grafana-editors editor
kanidm system oauth2 show-basic-secret grafana
# Generate new oauth2 app for proxied webapps
kanidm group create web-sentinel-access
kanidm group create web-sentinel-adguardhome-access
kanidm group create web-sentinel-influxdb-access
kanidm system oauth2 create web-sentinel "Web services" https://oauth2.${personalDomain}
kanidm system oauth2 update-scope-map web-sentinel web-sentinel-access openid email
kanidm system oauth2 update-sup-scope-map web-sentinel web-sentinel-adguardhome-access access_adguardhome
kanidm system oauth2 update-sup-scope-map web-sentinel web-sentinel-influxdb-access access_influxdb
kanidm system oauth2 show-basic-secret web-sentinel
# Add new user
kanidm login --name idm_admin
kanidm person create myuser "My User"
kanidm person update myuser --legalname "Full Name" --mail "myuser@example.com"
kanidm group add-members grafana-access myuser
kanidm group add-members grafana-server-admins myuser
kanidm group add-members web-sentinel-access myuser
kanidm group add-members web-sentinel-adguardhome-access myuser
kanidm group add-members web-sentinel-influxdb-access myuser

# TODO influxdb temporary pw d0lRidLSqZ03W5BBjQ7Id3oM2zVE5jLrRUKcMXeYDk5WGabb
```




