# Uses sire's evaluated settings and the same nginx routes as both frontends.
{
  pkgs,
  agenix,
  agenix-rekey,
  gatewaySettings,
}:
let
  bootstrap = "disposable-gateway-test-bootstrap";
  fixtures =
    pkgs.runCommand "ai-gateway-test-secrets"
      {
        nativeBuildInputs = [
          pkgs.openssh
          pkgs.rage
        ];
      }
      ''
        mkdir -p "$out"
        ssh-keygen -q -t ed25519 -N "" -f "$out/identity"
        printf '%s\n' '${bootstrap}' | rage -R "$out/identity.pub" -o "$out/bootstrap.age"
        printf '%s\n' 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=' \
          | rage -R "$out/identity.pub" -o "$out/encryption.age"
        for key in operator chatonly limited; do
          ${pkgs.python3}/bin/python3 ${../../../modules/antirion-keygen.py} \
            | rage -R "$out/identity.pub" -o "$out/$key.age"
        done
      '';
in
pkgs.testers.runNixOSTest {
  name = "sire-ai-gateway";
  nodes = {
    gateway =
      {
        config,
        lib,
        nodes,
        ...
      }:
      {
        imports = [
          agenix.nixosModules.default
          agenix-rekey.nixosModules.default
          ../../../modules/antirion.nix
        ];
        services.antirion = {
          enable = true;
          package = pkgs.antirion;
          settings = lib.recursiveUpdate gatewaySettings {
            security.client_ip.trusted_proxies = [ "${nodes.proxy.networking.primaryIPAddress}/32" ];
            keys = {
              chatonly = {
                owner = "operator";
                secret._secret = config.age.secrets.antirion-chatonly.path;
                models = [ "orcarouter-qwen38-27b" ];
                providers = [ "llamacpp" ];
              };
              limited = {
                owner = "operator";
                secret._secret = config.age.secrets.antirion-limited.path;
                providers = [ "oxr" ];
                policies.limits.rpm = {
                  unit = "requests";
                  limit = 2;
                  per = "1m";
                };
              };
            };
          };
        };
        age.identityPaths = [ "${fixtures}/identity" ];
        age.rekey.extraEncryptionPubkeys = [
          "age1qyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqs3290gq"
        ];
        age.secrets = {
          antirion-bootstrap-token = {
            generator = lib.mkForce null;
            file = "${fixtures}/bootstrap.age";
          };
          antirion-encryption-key = {
            generator = lib.mkForce null;
            file = "${fixtures}/encryption.age";
          };
          antirion-operator.file = "${fixtures}/operator.age";
          antirion-chatonly.file = "${fixtures}/chatonly.age";
          antirion-limited.file = "${fixtures}/limited.age";
        };
        systemd.services.mock-ai = {
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            ExecStart = "${pkgs.python3}/bin/python3 ${./mock-ai.py}";
            RuntimeDirectory = "mock-ai";
          };
        };
        networking.firewall.allowedTCPPorts = [ 8080 ];
        environment.systemPackages = [
          pkgs.curl
          pkgs.sqlite
        ];
        virtualisation.memorySize = 2048;
      };
    proxy = { nodes, ... }: {
      services.nginx = {
        enable = true;
        recommendedProxySettings = true;
      }
      // (import ../antirion-proxy.nix {
        domain = "ai.example.test";
        upstream = "${nodes.gateway.networking.primaryIPAddress}:8080";
      });
      networking.firewall.allowedTCPPorts = [ 80 ];
      environment.systemPackages = [ pkgs.curl ];
      virtualisation.memorySize = 512;
    };
  };
  testScript = ''
    import json
    import shlex

    def request(path, key=None, payload=None, args=None):
        command = ["curl", "-sS", "--max-time", "20", "-w", "\\n%{http_code}",
                   "-H", "Host: ai.example.test", "http://127.0.0.1" + path]
        if key:
            command += ["-H", "Authorization: Bearer " + key]
        if payload is not None:
            command += ["-H", "Content-Type: application/json", "--data-binary", json.dumps(payload)]
        command += args or []
        body, code = proxy.succeed(shlex.join(command)).rsplit("\n", 1)
        return int(code), body

    def query(sql):
        return json.loads(gateway.succeed(shlex.join([
            "sqlite3", "-json", "/var/lib/private/antirion/logs.db", sql
        ])))

    start_all()
    gateway.wait_for_unit("mock-ai.service")
    gateway.wait_for_unit("antirion.service")
    gateway.wait_until_succeeds("curl -fsS http://127.0.0.1:8080/-/readyz")
    proxy.wait_for_unit("nginx.service")
    keys = {name: gateway.succeed("cat /run/agenix/antirion-" + name).strip()
            for name in ["operator", "chatonly", "limited"]}
    key = keys["operator"]

    with subtest("only authenticated data APIs are exposed"):
        for path in ["/v1/models", "/oxr/v1/artifacts/job/image.png", "/v1/artifacts/job/image.png"]:
            assert request(path)[0] == 401, path
        assert request("/v1/models", "invalid-key")[0] == 401
        assert request("/v1/audio/speech", args=[
            "-X", "OPTIONS", "-H", "Origin: http://localhost:8081",
            "-H", "Access-Control-Request-Method: POST",
            "-H", "Access-Control-Request-Headers: authorization,content-type"
        ])[0] == 204
        for path in ["/", "/ui/", "/admin/v1/keys", "/health"]:
            assert request(path, key)[0] == 404, path
        for port in [8081, 11434, 11435, 11436, 11437, 11438]:
            proxy.fail(f"curl -fsS --connect-timeout 2 --max-time 2 http://gateway:{port}/")
        code, body = request("/v1/models", key)
        assert code == 200, body
        assert {m["id"] for m in json.loads(body)["data"]} == {"orcarouter-qwen38-27b", "omnivoice-tts"}

    with subtest("Qwen non-streaming and SSE"):
        payload = {"model": "orcarouter-qwen38-27b",
                   "messages": [{"role": "user", "content": "Hello"}]}
        code, body = request("/v1/chat/completions", key, payload,
                             ["-H", "X-Forwarded-For: 203.0.113.123"])
        assert code == 200 and json.loads(body)["choices"][0]["message"]["content"] == "Hello", body
        code, body = request("/v1/chat/completions", key, {
            **payload, "stream": True, "stream_options": {"include_usage": True}
        })
        assert code == 200 and "[DONE]" in body and "Hello" in body, body

    with subtest("OmniVoice binary speech and provider access restrictions"):
        speech = {"model": "omnivoice-tts", "input": "Hello", "voice": "alloy",
                  "response_format": "wav", "language": "en"}
        # Write binary to disk rather than decoding it as the test driver's stdout.
        code, _ = request("/v1/audio/speech", key, speech, ["-o", "/tmp/speech.wav"])
        assert code == 200
        proxy.succeed("test $(stat -c %s /tmp/speech.wav) -gt 44")
        assert request("/v1/audio/speech", keys["chatonly"], speech)[0] == 403
        assert request("/oxr/v1/artifacts/job/image.png", keys["chatonly"])[0] == 403

    with subtest("OXR multipart, async polling, and authenticated artifact URLs"):
        proxy.succeed("printf fixture-document > /tmp/document.pdf")
        form = ["-F", "api_key=unused", "-F", "file=@/tmp/document.pdf"]
        for endpoint in ["sync", "async"]:
            code, body = request("/oxr/v1/parse/" + endpoint, key, args=form)
            assert code == 200, body
            assert json.loads(body)["data"]["image"] == "/v1/artifacts/job/image.png"
        code, body = request("/oxr/v1/parse/async_check", key,
                             args=["-d", "api_key=unused&task_id=test-task"])
        assert code == 200 and json.loads(body)["data"]["status"] == "success", body
        for path in ["/oxr/v1/artifacts/job/image.png?download=1", "/v1/artifacts/job/image.png"]:
            assert request(path, key) == (200, "test-image")
        assert request("/oxr/v1/artifacts/job/image.png", key, args=["-X", "DELETE"])[0] == 405

    with subtest("passthrough is request-limited per key"):
        for _ in range(2):
            assert request("/oxr/v1/parse/sync", keys["limited"], args=form)[0] == 200
        assert request("/oxr/v1/parse/sync", keys["limited"], args=form)[0] == 429

    with subtest("usage ownership, streaming token accounting, and no upstream credentials"):
        gateway.wait_until_succeeds(
            "test $(sqlite3 /var/lib/private/antirion/logs.db "
            + shlex.quote("SELECT COUNT(*) FROM request_logs WHERE model='orcarouter-qwen38-27b' AND status_code=200")
            + ") -ge 2")
        rows = query("SELECT key_name, user_name, input_tokens, output_tokens, client_ip "
                     "FROM request_logs WHERE model='orcarouter-qwen38-27b' AND status_code=200")
        assert len(rows) == 2, rows
        assert all(r["key_name"] == "operator" and r["user_name"] == "operator" for r in rows), rows
        assert all(r["input_tokens"] == 7 and r["output_tokens"] == 5 for r in rows), rows
        assert all(r["client_ip"] != "203.0.113.123" for r in rows), rows
        # Request logs are flushed asynchronously; the last successful call may
        # not have reached SQLite yet even though the earlier chat rows have.
        gateway.wait_until_succeeds(
            "test $(sqlite3 /var/lib/private/antirion/logs.db "
            + shlex.quote("SELECT COUNT(*) FROM request_logs WHERE route=\'passthrough:oxr\' AND status_code=200")
            + ") -ge 7")
        speech = query("SELECT key_name, user_name FROM request_logs "
                       "WHERE model=\'omnivoice-tts\' AND status_code=200")
        assert speech == [{"key_name": "operator", "user_name": "operator"}], speech
        oxr = query("SELECT key_name, user_name FROM request_logs "
                    "WHERE route=\'passthrough:oxr\' AND status_code=200")
        assert len(oxr) == 7 and all(r["user_name"] == "operator" for r in oxr), oxr
        seen = [json.loads(line) for line in gateway.succeed("cat /run/mock-ai/requests.jsonl").splitlines()]
        assert {r["port"] for r in seen} == {11434, 11435, 11438}
        assert all(r["authorization"] is None for r in seen)
        assert any(r["path"].endswith("?download=1") for r in seen)
  '';
}
