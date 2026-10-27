# Run with pkgs from this repo's overlay and the two corresponding flake inputs.
{
  pkgs,
  agenix,
  agenix-rekey,
}:
let
  # These are disposable test credentials, deliberately NOT real secrets.
  bootstrap = "antirion-test-bootstrap-token-not-for-production";
  encryptionKey = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  dummyRecipient = "age1qyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqs3290gq";
  prunedSettings = pkgs.lib.genAttrs [ "providers" "deployments" "models" "keys" "users" ] (
    _: pkgs.lib.mkForce { }
  );
  fixtures =
    pkgs.runCommand "antirion-test-credentials"
      {
        nativeBuildInputs = [
          pkgs.openssh
          pkgs.rage
        ];
      }
      ''
        mkdir -p "$out"
        ssh-keygen -q -t ed25519 -N "" -f "$out/host-key"
        printf '%s\n' '${bootstrap}' | rage -R "$out/host-key.pub" -o "$out/bootstrap.age"
        ${pkgs.python3}/bin/python3 ${../antirion-keygen.py} \
          | rage -R "$out/host-key.pub" -o "$out/friend.age"
        printf '%s\n' '${encryptionKey}' | rage -R "$out/host-key.pub" -o "$out/encryption.age"
      '';
in
pkgs.testers.runNixOSTest {
  name = "antirion";

  nodes.machine = { config, lib, ... }: {
    imports = [
      agenix.nixosModules.default
      agenix-rekey.nixosModules.default
      ../antirion.nix
    ];
    services.antirion = {
      enable = true;
      package = pkgs.antirion;
      settings = {
        providers.local = {
          type = "openai_compatible";
          base_url = "http://127.0.0.1:9999";
          auth.method = "none";
        };
        deployments.chat = {
          provider = "local";
          model = "test-model";
        };
        models.chat.target = "chat";
        users.friend.email = "friend@example.invalid";
        keys.friend = {
          secret._secret = config.age.secrets.antirion-friend.path;
          owner = "friend";
          models = [ "chat" ];
          policies.limits.rpm = {
            unit = "requests";
            limit = 30;
            per = "1m";
          };
        };
      };
    };

    # Exercise real agenix activation and root-only files. Bypass generation and
    # rekeying only for these test fixtures; never touch the repo's real secrets.
    # Activation decrypts before environment.etc is installed on first boot.
    # This private key is a disposable test fixture, safe to keep in the store.
    age.identityPaths = [ "${fixtures}/host-key" ];
    age.rekey.extraEncryptionPubkeys = [ dummyRecipient ];
    age.secrets = {
      antirion-bootstrap-token = {
        generator = lib.mkForce null;
        file = "${fixtures}/bootstrap.age";
      };
      antirion-encryption-key = {
        generator = lib.mkForce null;
        file = "${fixtures}/encryption.age";
      };
      antirion-friend.file = "${fixtures}/friend.age";
    };
    environment.systemPackages = [
      pkgs.curl
      pkgs.jq
    ];
    virtualisation.memorySize = 2048;

    # Change the declaration via a real NixOS switch, rather than editing the
    # generated runtime file which ExecStartPre would correctly overwrite.
    specialisation = {
      pruned.configuration.services.antirion = {
        settings = prunedSettings;
        retiredKeyFiles.friend = config.age.secrets.antirion-friend.path;
      };
      retired.configuration.services.antirion.settings = prunedSettings;
    };
  };

  testScript = ''
    import json
    import shlex

    def request(path, *, admin=False, method="GET", payload=None, headers=None, key=None):
        port = 8081 if admin else 8080
        args = ["curl", "--silent", "--show-error", "--max-time", "10",
                "--write-out", "\\n%{http_code}", "-X", method,
                f"http://127.0.0.1:{port}{path}"]
        if key:
            args += ["-H", f"Authorization: Bearer {key}"]
        for header in headers or []:
            args += ["-H", header]
        if payload is not None:
            args += ["-H", "Content-Type: application/json", "--data-binary", json.dumps(payload)]
        body, code = machine.succeed(shlex.join(args)).rsplit("\n", 1)
        return int(code), body

    def admin(path, **kwargs):
        return request("/admin/v1" + path, admin=True, key="${bootstrap}", **kwargs)

    def ready():
        machine.wait_for_unit("antirion.service", timeout=60)
        machine.wait_until_succeeds("curl --fail --silent http://127.0.0.1:8080/-/readyz", timeout=60)

    start_all()
    ready()
    friend_key = machine.succeed("cat /run/agenix/antirion-friend").strip()
    base_system = machine.succeed("readlink -f /run/current-system").strip()
    with subtest("dynamic user, private state, and credential substitution"):
        assert machine.succeed("systemctl show antirion -p DynamicUser --value").strip() == "yes"
        assert machine.succeed("stat -Lc '%a' /run/antirion/config.json").strip() == "600"
        assert machine.succeed("stat -Lc '%U:%a' /run/agenix/antirion-friend").strip() == "root:400"
        machine.fail("su -s /bin/sh nobody -c 'test -r /run/antirion/config.json'")
        machine.fail("su -s /bin/sh nobody -c 'test -r /run/agenix/antirion-friend'")
        settings = json.loads(machine.succeed("cat /run/antirion/config.json"))
        assert settings["keys"]["friend"]["secret"].startswith("$" + "{file:/run/credentials/antirion.service/key-")
        assert friend_key not in json.dumps(settings)
        assert settings["security"]["secrets"]["encryption_keys"] == ["${encryptionKey}"]
        assert "_secret" not in json.dumps(settings)
        machine.succeed("test -f /var/lib/private/antirion/state.db")
        machine.succeed("test -f /var/lib/private/antirion/logs.db")

    with subtest("console and data authentication"):
        code, body = request("/ui/", admin=True)
        assert code == 200 and "<html" in body.lower()
        assert request("/v1/models")[0] == 401
        code, body = request("/v1/models", key=friend_key)
        assert code == 200, body
        assert any(model["id"] == "chat" for model in json.loads(body)["data"])

    with subtest("declarative ownership and API edit locking"):
        code, body = admin("/providers/local")
        assert code == 200, body
        assert "apply:nixos" in body, body
        code, body = admin("/providers/local", method="PATCH",
                           headers=["If-Match: *"], payload={"spec": {"base_url": "http://127.0.0.1:9998"}})
        assert code == 409 and "managed_by_apply" in body, (code, body)
        # An API-created object must survive both restart and pruning.
        code, body = admin("/providers/manual", method="PUT", headers=["If-None-Match: *"],
                           payload={"spec": {"type": "openai_compatible", "base_url": "http://127.0.0.1:9997",
                                             "auth": {"method": "none"}}})
        assert code == 201, (code, body)

    with subtest("restart preserves SQLite state and encryption key"):
        machine.succeed("systemctl restart antirion")
        ready()
        assert admin("/providers/manual")[0] == 200
        assert request("/v1/models", key=friend_key)[0] == 200

    with subtest("NixOS switch prunes only apply-owned resources"):
        machine.succeed(f"{base_system}/specialisation/pruned/bin/switch-to-configuration test")
        ready()
        assert admin("/providers/local")[0] == 404
        assert admin("/keys/friend")[0] == 404
        assert admin("/providers/manual")[0] == 200
        assert request("/v1/models", key=friend_key)[0] == 401

    with subtest("retired credential can be dropped after pruning"):
        machine.succeed(f"{base_system}/specialisation/retired/bin/switch-to-configuration test")
        ready()
        machine.succeed("rm /run/agenix/antirion-friend")
        machine.succeed("systemctl restart antirion")
        ready()
        assert admin("/keys/friend")[0] == 404
        assert request("/v1/models", key=friend_key)[0] == 401
        assert admin("/providers/manual")[0] == 200

    with subtest("missing secret fails closed"):
        machine.succeed("systemctl stop antirion")
        machine.succeed("rm /run/agenix/antirion-encryption-key")
        machine.fail("systemctl start antirion")
        machine.fail("curl --fail --silent http://127.0.0.1:8080/-/readyz")
        machine.succeed("systemctl stop antirion")
  '';
}
