{
  mixReleaseName, # "domain" "web" or "api"
}:
{
  lib,
  fetchFromGitHub,
  beamPackages,
  pnpm_9,
  nodejs,
  tailwindcss,
  esbuild,
}:

beamPackages.mixRelease rec {
  pname = "firezone-server-${mixReleaseName}";
  version = "unstable-2025-01-19";

  src = "${
    fetchFromGitHub {
      owner = "firezone";
      repo = "firezone";
      rev = "8c9427b7b133e5050be34c2ac0e831c12c08f02c";
      hash = "sha256-yccplADHRJQQiKrmHcJ5rvouswHrbx4K6ysnIAoZJR0=";
    }
  }/elixir";
  patches = [ ./a.patch ];

  pnpmDeps = pnpm_9.fetchDeps {
    inherit pname version;
    src = "${src}/apps/web/assets";
    hash = "sha256-6rhhGv3jQY5MkOMNe1GEtNyrzJYXCSzvo8RLlKelP10=";
  };
  pnpmRoot = "apps/web/assets";

  preBuild = ''
    cat >> config/config.exs <<EOF
    config :tailwind, path: "${lib.getExe tailwindcss}"
    config :esbuild, path: "${lib.getExe esbuild}"
    EOF

    cat >> config/runtime.exs <<EOF
    config :tzdata, :data_dir, System.get_env("TZDATA_DIR")
    EOF

    # TODO replace https://firezone.statuspage.io with custom link,
    # unfortunately simple replace only works at compile time
  '';

  postBuild = ''
    pushd apps/web
    # for external task you need a workaround for the no deps check flag
    # https://github.com/phoenixframework/phoenix/issues/2690
    mix do deps.loadpaths --no-deps-check, assets.deploy
    mix do deps.loadpaths --no-deps-check, phx.digest priv/static
    popd
  '';

  nativeBuildInputs = [
    pnpm_9
    pnpm_9.configHook
    nodejs
  ];

  inherit mixReleaseName;

  # https://github.com/elixir-cldr/cldr_numbers/pull/52
  mixNixDeps = import ./mix.nix {
    inherit lib beamPackages;
    overrides =
      final: prev:
      (lib.mapAttrs (
        _: value:
        value.override {
          appConfigPath = src + "/config";
        }
      ) prev)
      // {
        ex_cldr_numbers = beamPackages.buildMix rec {
          name = "ex_cldr_numbers";
          version = "2.33.4";

          src = beamPackages.fetchHex {
            pkg = "ex_cldr_numbers";
            version = "${version}";
            sha256 = "sha256-0Vt+IX6eYMMo5zBF5R3GfXrF0plyR7gz76ssabLtBvU=";
          };

          beamDeps = [
            final.decimal
            final.digital_token
            final.ex_cldr
            final.ex_cldr_currencies
            final.jason
          ];
        };

        # mix2nix does not support git dependencies yet,
        # so we need to add them manually
        openid_connect = beamPackages.buildMix {
          name = "openid_connect";
          version = "2024-06-15-unstable";

          src = fetchFromGitHub {
            owner = "firezone";
            repo = "openid_connect";
            rev = "e4d9dca8ae43c765c00a7d3dfa12d6f24f5b3418";
            hash = "sha256-LMmG+WWs83Hw/jcrersUMpk2tdXxkOU0CTe7qVbk6GQ=";
          };
          beamDeps = [
            final.jason
            final.finch
            final.jose
          ];
        };
      };
  };

  meta = {
    description = "Backend server and Admin UI for the Firezone zero-trust access platform";
    homepage = "https://github.com/firezone/firezone";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [
      oddlama
      patrickdag
    ];
    mainProgram = mixReleaseName;
    platforms = lib.platforms.linux;
  };
}
