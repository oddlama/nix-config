{
  path,
  fetchFromGitHub,
  lib,
  openssl,
  pkg-config,
  protobuf,
  rustPlatform,
  stdenv,
}:

# Pinned to the engines that AFFiNE's yarn.lock resolves to: it depends on
# @prisma/engines-version 6.8.0-43.2060c79ba17c6bb9f5823312b6f6b7f4a845738e,
# and the 6.8.2 tag of this repository is exactly that commit (6.8.0, 6.8.1
# and 6.8.2 all point at it). Keep this in sync with the `prisma` and
# `@prisma/client` versions in AFFiNE's lockfile when updating affine-server;
# prisma and prisma-engines must match for them to function correctly.
rustPlatform.buildRustPackage rec {
  pname = "prisma-engines";
  version = "6.8.2";

  src = fetchFromGitHub {
    owner = "prisma";
    repo = "prisma-engines";
    rev = version;
    hash = "sha256-YvP3yJQoe+q7jjpwntaYkYjxyoDzqnXcpIZa4Y+I/+E=";
  };

  cargoHash = "sha256-lRM5Ha0+f+srxYaosbCe/hhpzIPVc7f+ux4FFvISHmM=";

  # Use system openssl.
  OPENSSL_NO_VENDOR = 1;

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [ openssl ];

  preBuild = ''
    export OPENSSL_DIR=${lib.getDev openssl}
    export OPENSSL_LIB_DIR=${lib.getLib openssl}/lib

    export PROTOC=${protobuf}/bin/protoc
    export PROTOC_INCLUDE="${protobuf}/include";

    export SQLITE_MAX_VARIABLE_NUMBER=250000
    export SQLITE_MAX_EXPR_DEPTH=10000

    export GIT_HASH=0000000000000000000000000000000000000000
  '';

  cargoBuildFlags = [
    "-p"
    "query-engine"
    "-p"
    "query-engine-node-api"
    "-p"
    "schema-engine-cli"
    "-p"
    "prisma-fmt"
  ];

  postInstall = ''
    mv $out/lib/libquery_engine${stdenv.hostPlatform.extensions.sharedLibrary} $out/lib/libquery_engine.node
  '';

  # Tests are long to compile
  doCheck = false;

  setupHook = "${path}/pkgs/by-name/pr/prisma-engines_6/setup-hook.sh";

  meta = with lib; {
    description = "Collection of engines that power the core stack for Prisma";
    homepage = "https://www.prisma.io/";
    license = licenses.asl20;
    platforms = platforms.unix;
    mainProgram = "prisma";
    maintainers = with maintainers; [
      tomhoule
      aqrln
    ];
  };
}

### Troubleshooting
# Here's an example application using Prisma with Nix: https://github.com/pimeys/nix-prisma-example
# At example's `flake.nix` shellHook, notice the requirement of defining environment variables for prisma, it's values will show on `prisma --version`.
# Read the example's README: https://github.com/pimeys/nix-prisma-example/blob/main/README.md
# Prisma requires 2 packages, `prisma-engines` and `prisma`, to be at *exact* same versions.
# Certify at `package.json` that dependencies "@prisma/client" and "prisma" are equal, meaning no caret (`^`) in version.
# Configure NPM to use exact version: `npm config set save-exact=true`
# Delete `package-lock.json`, delete `node_modules` directory and run `npm install`.
# Run prisma client from `node_modules/.bin/prisma`.
# Run `./node_modules/.bin/prisma --version` and check if both prisma packages versions are equal, current platform is `linux-nixos`, and other keys equal to the prisma environment variables you defined for prisma.
# Test prisma with `generate`, `db push`, etc. It should work. If not, open an issue.
