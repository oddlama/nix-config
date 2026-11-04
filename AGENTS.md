# AGENTS.md

Personal NixOS flake (flake-parts) for all of malte's machines: workstations, home servers, and VPSes.
See `README.md` for the host list and service overview and `STRUCTURE.md` for a longer directory description.

## Where things are

- `flake.nix`: inputs, plus the list of flake-parts modules in `flake/`.
- `flake/hosts.nix`: every directory in `hosts/` automatically becomes a `nixosConfigurations.<name>` and a `nixosConfigurationsMinimal.<name>`. It also builds `nodes`, which holds all hosts **and** their guests.
- `flake/pkgs.nix` and `pkgs/default.nix`: the overlay list. Custom packages, backports, and temporary shims live here, and each has a comment saying when to drop it.
- `config/`: base config imported by every host and guest (`../../config`). `config/optional/`, `config/hardware/`, `config/graphical/`, and `config/dev/` are imported explicitly by hosts.
- `modules/`: reusable NixOS modules, all imported via `modules/default.nix`. Many more come from the `nixos-extra-modules` input (guests, wireguard, globals plumbing, `meta.*`, nftables zones, etc.). Check there when an option isn't defined in this repo.
- `hosts/<name>/`: `default.nix` (entry point), `net.nix`, `fs.nix` (disko), and service files. Hosts with guests (`sire`, `ward`) define them in `default.nix` via `mkMicrovm`/`mkContainer` and keep guest configs in `guests/<guest>.nix`, with `guests/common.nix` shared between them.
- `users/`: home-manager configs. `users/config/` is shared, `users/malte/` holds the personal dotfiles (niri, noctalia, nixvim, …), and `users/modules/` adds `userSecrets`.
- `globals.nix` and `modules/globals.nix`: the definition and schema of `globals` (networks, wireguard IDs, domains, services, monitoring). `flake/globals.nix` lists the allowed top-level keys.
- `topology/`: the nix-topology diagram config.
- `secrets/`: master/backup age pubkeys, `global.nix.age`, and the agenix-rekey output (`generated/<node>/`, `rekeyed/<node>/`).
- Tests: `modules/tests/`, `hosts/sire/tests/`, and `pkgs/tests/`. These are **not** wired into `flake checks`. They're run manually, and the invocation is in each file's header comment or in `modules/antirion.md`.

## Non-obvious things

- **Evaluation needs secrets.** `globals.nix` and each host's `secrets/local.nix.age` are age-encrypted Nix files that are decrypted *at eval time* through `builtins.exec` (`flake/extra-builtins.nix` → `rage-decrypt-and-cache.sh`, which needs the YubiKey). Evaluation only works inside the devshell (`direnv`/`nix develop` sets `allow-unsafe-native-code-during-evaluation`), or with `--option allow-unsafe-native-code-during-evaluation true`. Without the YubiKey you can't evaluate hosts, so don't keep retrying failed builds for that reason.
- **Two kinds of secrets:**
  - `config.repo.secrets.<name>` (`modules/secrets.nix`) holds PII such as MACs, IPs, names, and addresses. It ends up in the world-readable store and is only hidden from GitHub. User-level PII goes through `userSecrets` (`users/<u>/secrets/user.nix.age`).
  - `age.secrets.*` are real runtime secrets managed by agenix-rekey. The host key is `hosts/<node>/secrets/host.pub`, and guest secrets live in `hosts/<host>/secrets/<guest>/`. Many are generated (`generator.script`/`generator.dependencies`; custom generators are in `config/secrets.nix`). After adding one, run `agenix generate` and `agenix rekey`. These need the YubiKey and auto-`git add` their output.
- **Guest naming:** a guest `foo` on host `bar` becomes node `bar-foo` (e.g. `ward-kanidm`, `sire-immich`). Use that name in `nodes.*`, wireguard `hosts`, and `secrets/rekeyed/`.
- **Cross-node config (`modules/distributed-config.nix`):** a node can set `nodes.<other>.{age.secrets, services.nginx.virtualHosts/upstreams, kanidm provisioning, influxdb2 provisioning, nftables chains}`, and that config is merged into `<other>`. A service guest usually registers its own reverse-proxy vhost on `ward-web-proxy`/`sentinel` and its own OAuth2 client on `ward-kanidm` this way, so look for `nodes.` in the service file rather than in the proxy's config.
- **`globals` is writable from any node.** Service files set things like `globals.services.<x>.domain`, `globals.monitoring.*`, and `globals.wireguard.<net>.hosts.<node>.firewallRuleForNode...`, and other nodes read them. Wireguard host IDs live in `globals.nix` and must be unique per network.
- **Reverse proxy topology:** public traffic goes to `sentinel` (Hetzner), then over the `proxy-sentinel` wireguard to the guests. Home traffic goes to `ward-web-proxy` over `proxy-home`. `ward/default.nix` has a hand-maintained `homeDomains` list, and adguardhome has a matching list. Both need updating when a new home service is added.
- **Impermanence:** root is wiped on boot. `/state` holds data that's kept but disposable (ZFS `local/…` datasets: caches, logs), while `/persist` holds important data (`safe/…` datasets). Restic backups are configured separately in `modules/backups.nix`. Persistence declarations sit next to each service (`environment.persistence."/persist"...`, `home.persistence...`), not centrally. `config/impermanence.nix` forces `/var/lib/private` to stay `0700` so that `DynamicUser` services keep working.
- **`minimal` specialArg:** it's `true` for `nixosConfigurationsMinimal`, which the installer uses. Config that's heavy or needs secrets is wrapped in `lib.optionalAttrs (!minimal)` / `mkIf (!minimal)`, and guests are disabled when it's set.
- `flake/hosts.nix` hardcodes `pkgs = config.pkgs.x86_64-linux` (marked FIXME). `pkgsCuda` is also exposed for CUDA builds.
- `hardware.nvidia.modesetting.enable = true` in `config/default.nix` is there to avoid infinite recursion. Don't remove it.

## Workflow

- Devshell commands: `build <host>...` (nom build of the toplevel), `deploy <host,...> [switch|boot|test|dry-activate]`, `agenix`, `treefmt`.
- Formatting and linting: `treefmt` (nixfmt, deadnix, statix, and rustfmt) also runs as a pre-commit hook. Use `# deadnix: skip` to keep intentionally unused bindings.
- Commit messages are conventional commits, optionally scoped by host: `feat(sausebiene): …`, `fix: …`, `chore: update`.
