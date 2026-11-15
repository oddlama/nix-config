# AI gateway on sire

## Topology

Both nginx frontends (`ward-web-proxy` and `sentinel`) expose only
`https://ai.<globals.domains.me>`. The old `llm.` and `tts.` virtual hosts and
service registrations are removed, not redirected.

| Service | Listener | Remote access |
| --- | --- | --- |
| Antirion data plane | `0.0.0.0:8080` | Only the two nginx peers over WireGuard |
| Antirion admin/UI | `127.0.0.1:8081` | SSH tunnel only |
| Qwen/llama.cpp | `127.0.0.1:11434` | Through Antirion |
| OmniVoice HTTP | `127.0.0.1:11435` | Through Antirion |
| OXR layout | `127.0.0.1:11436` | Local OXR component only |
| OXR recognition | `127.0.0.1:11437` | Local OXR component only |
| OXR API | `127.0.0.1:11438` | Through Antirion |
| OmniVoice Wyoming | sire's `proxy-home` IPv4, port `10200` | Home Assistant (`sausebiene`) only |

The HTTP backends have no upstream authentication; Antirion providers use
`auth.method = "none"`. Do not make their listeners remotely reachable.
Local processes on sire can bypass the gateway; loopback is the trust boundary,
not per-process isolation. Wyoming deliberately remains outside gateway limits
and accounting.

OmniVoice's pinned release requires authentication. The local
`pkgs/omnivoice-loopback-no-auth.patch` adds explicit `--no-auth`, rejects
non-literal/non-loopback HTTP binds, and preserves the authenticated mode.
`environmentFile = "/dev/null"` satisfies the upstream NixOS module's credential
source assertion without loading or sending a token. Drop this compatibility
workaround when upstream supports this mode. Wyoming's address is independent.

## Provisioning and cutover

The declarations are enabled, but **generation/rekeying and deployment are
separate operational steps**. No production secrets are supplied by these files.
Before the first build/deployment, enter the repository's devshell and run:

```sh
agenix generate secrets/generated/sire/antirion-bootstrap-token.age \
  secrets/generated/sire/antirion-encryption-key.age \
  secrets/generated/sire/antirion-operator.age
agenix rekey
```

Review and commit the encrypted generated/rekeyed files. Never use forced
regeneration of the encryption key for an existing database. Build `sire`,
`sentinel`, and `ward-web-proxy` (via the normal guest workflow), then coordinate
their switches: switching sire first intentionally breaks the old direct
upstreams until the proxies switch. Do not use a temporary direct-backend bypass.
Update clients to the new base URL and Antirion credentials before handing out
access. Verify actual GPU inference, vision, streaming usage, speech, OXR and
Home Assistant after deployment; the protocol tests do not load model weights.

The initial `operator` key is for personal API access, with both models and OXR
allowed, 30 requests/minute and two concurrent requests. It is **not** an admin
credential and should not be shared. A gateway-wide ceiling allows eight
concurrent requests. Limits count HTTP calls (including OXR polls/downloads),
not pages or background jobs. No prices or monetary budgets are declared.
Qwen token usage is recorded when the backend reports it. Antirion v0.1.1's
request-log serializer leaves `usage.units` null; do not assume speech character
counts appear there even though its pricing machinery can compute them. Verify
non-token billing separately before introducing prices/budgets.

Add a separate owner and agenix-generated key per friend in `antirion.nix`:

```nix
age.secrets.antirion-alice.generator.script = "antirion-api-key";
services.antirion.settings = {
  users.alice = { email = "alice@example.org"; display_name = "Alice"; };
  keys.alice = {
    owner = "alice";
    secret._secret = config.age.secrets.antirion-alice.path;
    models = [ "orcarouter-qwen38-27b" "omnivoice-tts" ];
    providers = [ "llamacpp" "omnivoice" "oxr" ];
    policies.limits = {
      rpm = { unit = "requests"; limit = 30; per = "1m"; };
      concurrent = { unit = "concurrency"; limit = 2; };
    };
  };
};
```

Remove `oxr` from `providers` to deny parsing/artifacts; a model allow-list alone
is not a passthrough restriction. These are per-key limits: assigning multiple
keys to one owner does not combine their allowances. See
[the module documentation](../../modules/antirion.md) for two-switch key
retirement and declarative ownership/locking.

## Client endpoints

Send `Authorization: Bearer <Antirion key>`:

- OpenAI base URL: `https://ai.<domain>/v1`.
- Chat: `POST /v1/chat/completions`, model `orcarouter-qwen38-27b`.
- Speech: `POST /v1/audio/speech`, model `omnivoice-tts`. Supply `input`, `voice`
  and optionally `response_format`. Reference audio must be JSON/base64, not
  multipart, on this native route. Backend-specific JSON extensions are retained.
- OXR: `POST /oxr/v1/parse/sync` or `/oxr/v1/parse/async`, with multipart `file`
  and the upstream-required but **unvalidated** form field `api_key=unused`.
  Poll using `POST /oxr/v1/parse/async_check` and `task_id`.
- OXR artifact URLs beginning `/v1/artifacts/` work without rewriting the JSON.
  Nginx routes them through `/oxr/v1/artifacts/` on **Antirion**, so downloads also
  require a bearer key. Never send the gateway key in OXR's form `api_key` field.

Uploads are capped at 128 MiB at nginx/Antirion, with the backend's own limits
still applying (OmniVoice: 50 MiB). Proxy buffering is off; gateway/proxy request
allowances accommodate long inference. `/`, `/ui/`, and `/admin/` are not public.
Readiness monitoring checks Antirion, not individual GPU readiness.

OXR passthrough authenticates access to the shared service, **not ownership of
individual task IDs/artifacts**. All keys allowed the OXR provider share that
trust boundary. Only enable it for mutually trusted users. Review OXR's
[hosted-API license restriction](https://huggingface.co/SoMarkAI/OXR-1.0/blob/main/LICENSE)
before offering access; friends-only/free use is not automatically exempt.

## Administration and state

```sh
ssh -N -L 8081:127.0.0.1:8081 sire
```

Visit `http://localhost:8081/ui/`, using the administrative bootstrap credential
from `/run/agenix/antirion-bootstrap-token` on sire. The public data API permits
CORS from this private console origin only. Never distribute that credential as
an API key.

The DynamicUser backing directory `/var/lib/private/antirion` is persisted on
`/persist` with mode `0700`. Back up its SQLite state/log databases, WALs and spool
consistently, plus the encrypted encryption-key secret and decryption identities.
This change adds persistence, not a new backup job. The module docs cover restore
and encryption-key rotation precautions.

## Reproducible checks

From the repository root (all new source files must be tracked by Git):

```sh
nix eval --impure --json --expr '
  import ./hosts/sire/tests/eval.nix { flake = builtins.getFlake (toString ./.); }
'
nix-build --impure --no-out-link --max-jobs 2 --cores 2 --expr '
  let f = builtins.getFlake (toString ./.); in
  import ./hosts/sire/tests/antirion.nix {
    pkgs = f.pkgs.x86_64-linux;
    inherit (f.inputs) agenix agenix-rekey;
    gatewaySettings = f.nodes.sire.config.services.antirion.settings;
  }
'
nix-build --impure --no-out-link --max-jobs 2 --cores 4 --expr '
  let f = builtins.getFlake (toString ./.); in
  import ./pkgs/tests/omnivoice-loopback.nix {
    pkgs = f.pkgs.x86_64-linux;
    omnivoice = f.inputs.omnivoice-rs;
  }
'
```

The two-node gateway VM uses the actual sire settings and shared nginx routes,
with disposable credentials and loopback mock backends. It checks authentication,
provider permissions, request limits, chat/SSE usage attribution, binary speech,
OXR multipart/polling/artifacts, private ports, and absence of upstream tokens.
The CPU-only OmniVoice checks exercise the patched real server with a fake speech
runtime, including its unchanged Wyoming protocol.
