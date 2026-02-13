{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  rustPlatform,
  nodejs_22,
  yarn-berry_4,
  writableTmpDirAsHomeHook,
  cargo,
  rustc,
  openssl,
  findutils,
  gzip,
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

  # Prisma engines for version 6.8.2 (commit 2060c79ba17c6bb9f5823312b6f6b7f4a845738e)
  prismaEnginesCommit = "2060c79ba17c6bb9f5823312b6f6b7f4a845738e";
  prismaQueryEngine = fetchurl {
    url = "https://binaries.prisma.sh/all_commits/${prismaEnginesCommit}/debian-openssl-3.0.x/libquery_engine.so.node.gz";
    hash = "sha256-oOuR8XtO3I7NDUtx/JXjzHjBxDEFO8jv3x5CgccMzjc=";
  };
  prismaSchemaEngine = fetchurl {
    url = "https://binaries.prisma.sh/all_commits/${prismaEnginesCommit}/debian-openssl-3.0.x/schema-engine.gz";
    hash = "sha256-3Z76iqOAR5ytdfOkq5XQofnUveXqoqibNjaChGKisiM=";
  };
  prismaEngines = stdenv.mkDerivation {
    pname = "prisma-engines-affine";
    version = "6.8.2";
    dontUnpack = true;
    nativeBuildInputs = [ gzip ];
    installPhase = ''
      mkdir -p $out/lib $out/bin
      gunzip -c ${prismaQueryEngine} > $out/lib/libquery_engine.so.node
      gunzip -c ${prismaSchemaEngine} > $out/bin/schema-engine
      chmod +x $out/bin/schema-engine
    '';
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "affine-server";
  version = "0.26.2";
  src = fetchFromGitHub {
    owner = "toeverything";
    repo = "AFFiNE";
    tag = "v${finalAttrs.version}";
    hash = "sha256-qFJezmSNq6Uq6xvCGUITeidrChQiZWI6lw9ZX8PcwXc=";
  };

  patches = [
    ./0001-use-in-memory-graphql-schema.patch
    ./0002-disable-telemetry-by-default.patch
  ];

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) pname version src;
    hash = "sha256-3cvq3FV3juzEaKczw/SUHSXHLLEIEJlcv2LUAMxGVVQ=";
  };

  missingHashes = ./affine-server-missing-hashes.json;
  offlineCache = yarn-berry.fetchYarnBerryDeps {
    inherit (finalAttrs) src missingHashes;
    hash = "sha256-SOjBNwTnG+crTEme3KQt/MzbXo/a0vI2tGAqjYiCZgA=";
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
    GITHUB_SHA = finalAttrs.version;
    # force yarn install run in CI mode
    CI = "1";
    # Use pre-fetched Prisma engines (matching version 6.8.2)
    PRISMA_QUERY_ENGINE_LIBRARY = "${prismaEngines}/lib/libquery_engine.so.node";
    PRISMA_SCHEMA_ENGINE_BINARY = "${prismaEngines}/bin/schema-engine";
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

    # Copy the native module for all architectures
    cp packages/backend/native/server-native.node packages/backend/native/server-native.x64.node
    cp packages/backend/native/server-native.node packages/backend/native/server-native.arm64.node
    cp packages/backend/native/server-native.node packages/backend/native/server-native.armv7.node

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

    # Find the prisma query engine built by yarn (matches the prisma version in package.json)
    PRISMA_QUERY_ENGINE=$(find $out/node_modules/.prisma/client -name 'libquery_engine-debian-openssl-*.so.node' | head -1)
    PRISMA_SCHEMA_ENGINE=$(find $out/node_modules/@prisma/engines -name 'schema-engine-debian-openssl-*' -type f | head -1)

    makeWrapper ${lib.getExe nodejs} $out/bin/affine-server \
      --set NODE_ENV production \
      --set PRISMA_QUERY_ENGINE_LIBRARY "$PRISMA_QUERY_ENGINE" \
      --set PRISMA_SCHEMA_ENGINE_BINARY "$PRISMA_SCHEMA_ENGINE" \
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
