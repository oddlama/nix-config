# Antirion

`modules/antirion.nix` is imported by `modules/default.nix`; the overlay provides
`pkgs.antirion`. The module does not enable itself; `hosts/sire/antirion.nix`
now enables it on `sire`. See [the host runbook](../hosts/sire/antirion.md).

The module is intentionally tailored to a single gateway:

- Embedded SQLite state and request logs, plus the durable accounting spool.
- `DynamicUser` with private persistent and runtime directories.
- Declarative provisioning at startup (`source = "nixos"`, `prune = true`,
  `lock_applied = true`), rather than administrative API calls during activation.
- Root-readable agenix secrets passed through systemd `LoadCredential` and
  `utils.genJqSecretsReplacement`, including placeholders nested in lists.
- Configuration validation before starting; restart on configuration changes.
- Loopback listeners by default; no automatic firewall or reverse proxy setup.

## Provisioning a host

This example is intentionally not imported. Choose the host and actual backend
addresses/model names before using it:

```nix
{ config, ... }:
{
  age.secrets.antirion-alice.generator.script = "antirion-api-key";

  services.antirion = {
    enable = true;
    settings = {
      server.listen = "127.0.0.1:8080";
      admin.listen = "127.0.0.1:8081";
      auth.admin.public_origin = "https://ai-admin.example.org";
      admin.ui.data_plane_url = "https://ai.example.org";

      providers.llamacpp = {
        type = "openai_compatible";
        base_url = "http://llama.internal:8080/v1";
        auth.method = "none";
        # For an authenticated backend, instead use:
        # auth = {
        #   method = "api_key";
        #   api_key._secret = config.age.secrets.llama-api-key.path;
        # };
      };
      deployments.qwen = {
        provider = "llamacpp";
        model = "qwen"; # Must match the upstream model/alias.
      };
      models.qwen.target = "qwen";

      users.alice = {
        email = "alice@example.org";
        display_name = "Alice";
      };
      keys.alice = {
        secret._secret = config.age.secrets.antirion-alice.path;
        owner = "alice";
        models = [ "qwen" ];
        policies.limits = {
          rpm = { unit = "requests"; limit = 30; per = "1m"; };
          concurrent = { unit = "concurrency"; limit = 2; };
        };
      };
    };
  };
}
```

This example limits requests/concurrency; declare prices and budgets separately
if you also want monetary accounting/enforcement. The module accepts upstream
configuration under `settings`, rather than introducing a second configuration
schema for providers, users or policies.

For OpenAI-compatible native routes, include `/v1` in the provider's `base_url`;
Antirion appends paths such as `/chat/completions` and `/audio/speech`.
Passthrough instead appends the path below its mount unchanged.

For the other backends:

- Voxtral/vLLM: an `openai_compatible` provider with
  `capabilities.operations = [ "transcribe" ];`, a deployment/model, and
  `/v1/audio/transcriptions`.
- OmniVoice: the same with `capabilities.operations = [ "speech" ];` and
  `/v1/audio/speech`. Clients must supply `voice`; JSON/base64 reference audio
  works with this route, unlike multipart reference-audio uploads.
- OXR: an explicit `settings.api.passthrough.oxr` with `path_prefix = "/oxr"`,
  `provider = "oxr"` and `methods = [ "POST" ];`, pointing to an appropriately
  configured provider. `/oxr/v1/parse/sync` maps to upstream `/v1/parse/sync`.
  Allow that provider on the friends' keys. This provides request limiting,
  not extraction of page counts or OCR prices from responses.

Managed resources cannot be edited normally through the UI/API. Removing a
resource from the declaration prunes it on restart if it belongs to this apply
source and nothing retained still references it. Separately UI/API-created
resources are not pruned. Do not change `admin.config.source` casually: existing
resources would retain their old ownership.

### Retiring an API key (two switches)

**Antirion 0.1.1 restores its stored snapshot before applying pruning.** Removing
an API key's credential at the same time as its declaration therefore prevents
startup. For keys declared through `_secret`, use this explicit retirement step:

1. Remove `settings.keys.alice` (and any references to it), but retain the age
   secret and set:
   ```nix
   services.antirion.retiredKeyFiles.alice = config.age.secrets.antirion-alice.path;
   ```
2. Switch, wait for a healthy gateway, and confirm the key was actually pruned
   (e.g. it is absent in the admin UI/API). The old credential is available only
   so Antirion can restore its snapshot and then prune; it is not provisioned as
   a key by this option. Pruning must be enabled.
3. In a second switch, remove `retiredKeyFiles.alice` and the age secret.

Alternatively, keep a key declared with `enabled = false` to revoke access
without deleting its configuration. Do not remove its secret while it remains
declared. The module deliberately avoids persistent plaintext credential caches,
database edits, or administrative API calls during activation.

## Secrets

Enabling the module declares two agenix-rekey secrets:

- `antirion-bootstrap-token`: the administrative bootstrap credential (`alnum`).
- `antirion-encryption-key`: base64 of 32 bytes for stored-secret encryption
  (`base64`).

Run the repo's usual **agenix generate/rekey** workflow before deploying. No
secrets are generated, decrypted or committed by adding the module itself.
For friends' data-plane keys, use the module's
`generator.script = "antirion-api-key"`. Antirion requires its own checksummed
key format; ordinary `alnum` passwords are not accepted as virtual keys. The
generator follows upstream's format and uses Python's OS-backed `secrets` RNG.
Upstream-provider credentials can reference existing rekeyed secrets. Leave their ownership/mode at root/0400; no static service group or
secret chown is necessary.

The defaults can be overridden through `settings.auth.admin.bootstrap_token`
and `settings.security.secrets.encryption_keys`. Use `_secret` placeholders,
not plaintext literals, Nix path literals to plaintext files, or
`builtins.readFile`. Only paths/placeholders are in the Nix store; the rendered
configuration is private at `/run/antirion/config.json` (0600).

Antirion requires declared API keys to be references, never literal values.
The module therefore translates `keys.<name>.secret._secret` to native file
references to stable, per-key systemd credentials, rather than putting the key
value in the rendered JSON. The referenced file must contain the raw key;
`quote = false` is not supported for this field. Other secret fields use normal
JSON substitution, including the encryption-key list.

Referenced agenix secrets' encrypted `.file` inputs are restart triggers, so a
normal NixOS switch after rekeying picks up their changed values. For arbitrary
non-agenix `_secret` files, restart `antirion.service` after changing contents.

## Persistence and backups

Inside the service, state lives at `/var/lib/antirion`; with `DynamicUser`, the
host-side backing directory is **`/var/lib/private/antirion`**. On an impermanent
host, persist that backing directory using the host's existing impermanence
configuration. The module does not choose a persistence volume for you.

Back up the entire state directory (including `state.db`, `logs.db`, their WALs
and the spool), preferably with the service stopped or using a consistent
filesystem snapshot. Also retain the encrypted agenix encryption-key secret
and the identities needed to decrypt/rekey it. The declaration alone cannot
restore accounting history, balances or UI-created state.

Do not simply regenerate the encryption key for an existing database. For key
rotation, follow upstream's rotation procedure and retain old keys in the
`security.secrets.encryption_keys` list until they are no longer needed; the
first key is used for encryption.

The embedded UI is built for `/ui`. Keep the admin plane private or put it
behind authenticated HTTPS. Configure the public origin, proxy trust and any
needed CORS settings explicitly when adding the reverse proxy.

## Tests

`modules/tests/antirion.nix` is a NixOS VM test accepting `pkgs` from this overlay
and the `agenix` / `agenix-rekey` flake inputs. It uses disposable encrypted test
fixtures, not any host's secrets. It covers credential substitution, filesystem
permissions, DynamicUser, startup, authentication, UI serving, declarative
ownership/edit locking, restart persistence, pruning and two-switch key
retirement, and failure when a required credential is missing.

After adding the new files to Git, run it from the repo root with:

```sh
nix-build --impure --no-out-link --max-jobs 2 --cores 2 --expr '
  let f = builtins.getFlake (toString ./.); in
  import ./modules/tests/antirion.nix {
    pkgs = f.pkgs.x86_64-linux;
    inherit (f.inputs) agenix agenix-rekey;
  }
'
```

`hosts/sire/tests/antirion.nix` additionally tests nginx routing, chat/SSE,
speech, OXR passthrough/artifacts, permissions and accounting with mock backends.
Real GPU inference and backend-reported usage still need deployment-time testing.
