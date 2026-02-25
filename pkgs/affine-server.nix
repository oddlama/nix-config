{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  nodejs_22,
  yarn-berry_4,
  prisma-engines,
  writableTmpDirAsHomeHook,
  cargo,
  rustc,
  openssl,
  findutils,
  zip,
  rsync,
  jq,
  makeWrapper,
  nix-update-script,
  testers,
}:
let
  nodejs = nodejs_22;
  yarn-berry = yarn-berry_4.override { inherit nodejs; };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "affine-server";
  version = "0.26.3";
  src = fetchFromGitHub {
    owner = "toeverything";
    repo = "AFFiNE";
    tag = "v${finalAttrs.version}";
    hash = "sha256-r7sjiaHgqWPOFXHTFJ/orOog7VtBmKt4x2YCsI+L9+g=";
  };

  patches = [
    ./0001-dont-try-to-write-schema.gql-into-nix-store.patch
    ./0002-chore-disable-telemetry-by-default.patch
  ];

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) pname version src;
    hash = "sha256-vZkKFUaNe9iIAkdUfXnnuD2lM6kuzwqj1Dyt5GAgXsM=";
  };

  missingHashes = ./affine-server-hashes.json;
  offlineCache = yarn-berry.fetchYarnBerryDeps {
    inherit (finalAttrs) src missingHashes;
    hash = "sha256-z5kBWw6xp1y6H845pVp3DFcmSEklYdVcP2yPULxpIfw=";
  };

  nativeBuildInputs = [
    nodejs
    yarn-berry
    yarn-berry.yarnBerryConfigHook
    cargo
    rustc
    findutils
    openssl
    zip
    jq
    rsync
    writableTmpDirAsHomeHook
    makeWrapper
  ];

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    PRISMA_QUERY_ENGINE_LIBRARY = "${prisma-engines}/lib/libquery_engine.node";
    PRISMA_SCHEMA_ENGINE_BINARY = "${prisma-engines}/bin/schema-engine";
    GITHUB_SHA = finalAttrs.version;
    # force yarn install run in CI mode
    CI = "1";
  };

  configurePhase = ''
    runHook preConfigure

    # cargo config
    mkdir -p .cargo
    cat $cargoDeps/.cargo/config.toml >> .cargo/config.toml
    ln -s $cargoDeps @vendor@

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    yarn install
    CARGO_NET_OFFLINE=true yarn affine @affine/server-native build

    # yikes, pls no
    cp packages/backend/native/server-native.node packages/backend/native/server-native.x64.node
    cp packages/backend/native/server-native.node packages/backend/native/server-native.arm64.node
    cp packages/backend/native/server-native.node packages/backend/native/server-native.armv7.node

    yarn affine @affine/reader build
    yarn affine @affine/server build
    yarn affine @affine/web build
    yarn affine @affine/admin build
    yarn affine @affine/mobile build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir $out/{,bin}

    cp -r node_modules $out/node_modules
    cp -r packages/backend/server/dist $out/dist
    cp -r packages/backend/server/schema.prisma $out
    cp -r packages/backend/server/migrations $out

    cp -r packages/frontend/apps/web/dist $out/static
    cp -r packages/frontend/admin/dist $out/static/admin
    cp -r packages/frontend/apps/mobile/dist $out/static/mobile

    makeWrapper ${lib.getExe nodejs} $out/bin/affine-server \
      --set NODE_ENV production \
      --set PRISMA_QUERY_ENGINE_LIBRARY "${prisma-engines}/lib/libquery_engine.node" \
      --set PRISMA_SCHEMA_ENGINE_BINARY "${prisma-engines}/bin/schema-engine" \
      --prefix PATH : ${
        lib.makeBinPath [
          openssl
          nodejs
        ]
      } \
      --run "$out/node_modules/.bin/prisma migrate deploy" \
      --run "$out/node_modules/.bin/cross-env SERVER_FLAVOR=script ${lib.getExe nodejs} $out/dist/main.js run" \
      --add-flags "$out/dist/main.js"

    # remove dangling symlinks
    find $out -xtype l -delete

    runHook postInstall
  '';

  passthru = {
    test = testers.runNixOSTest {
      name = "affine-server-test";

      # One or more machines:
      nodes = {
        machine =
          { config, ... }:
          {
            imports = [ ../modules/affine.nix ];
            services.affine = {
              enable = true;
              enableLocalDB = true;
              settings.server = {
                name = "Test server";
                host = "0.0.0.0";
                externalUrl = "http://localhost:3010";
              };
            };

            networking.firewall.allowedTCPPorts = [ config.services.affine.settings.server.port ];
            virtualisation.forwardPorts = [
              {
                from = "host";
                host.port = config.services.affine.settings.server.port;
                guest.port = config.services.affine.settings.server.port;
              }
            ];
          };
      };

      testScript = ''
        machine.start()
        machine.wait_for_unit("affine.service")
        machine.wait_for_open_port(3010)
      '';
    };
    updateScript = nix-update-script {
      extraArgs = [
        "--version-regex=^v(\\d+\\.\\d+\\.\\d+)$"
      ];
    };
  };

  meta = {
    description = "AFFiNE server";
    longDescription = ''
      Server for AFFiNE. AFFiNE is an open-source, all-in-one workspace
      and an operating system for all the building blocks that assemble your
      knowledge base and much more -- wiki, knowledge management, presentation
      and digital assets
    '';
    homepage = "https://affine.pro/";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ oddlama ];
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    mainProgram = "affine-server";
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
})
