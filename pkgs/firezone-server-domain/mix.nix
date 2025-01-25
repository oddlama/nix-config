{
  lib,
  beamPackages,
  overrides ? (_x: _y: { }),
}:

let
  buildRebar3 = lib.makeOverridable beamPackages.buildRebar3;
  buildMix = lib.makeOverridable beamPackages.buildMix;
  buildErlangMk = lib.makeOverridable beamPackages.buildErlangMk;

  self = packages // (overrides self packages);

  packages =
    with beamPackages;
    with self;
    {
      acceptor_pool = buildRebar3 rec {
        name = "acceptor_pool";
        version = "1.0.0";

        src = fetchHex {
          pkg = "acceptor_pool";
          version = "${version}";
          sha256 = "0cbcd83fdc8b9ad2eee2067ef8b91a14858a5883cb7cd800e6fcd5803e158788";
        };

        beamDeps = [ ];
      };

      argon2_elixir = buildMix rec {
        name = "argon2_elixir";
        version = "4.0.0";

        src = fetchHex {
          pkg = "argon2_elixir";
          version = "${version}";
          sha256 = "f9da27cf060c9ea61b1bd47837a28d7e48a8f6fa13a745e252556c14f9132c7f";
        };

        beamDeps = [
          comeonin
          elixir_make
        ];
      };

      bandit = buildMix rec {
        name = "bandit";
        version = "1.5.7";

        src = fetchHex {
          pkg = "bandit";
          version = "${version}";
          sha256 = "f2dd92ae87d2cbea2fa9aa1652db157b6cba6c405cb44d4f6dd87abba41371cd";
        };

        beamDeps = [
          hpax
          plug
          telemetry
          thousand_island
          websock
        ];
      };

      bunt = buildMix rec {
        name = "bunt";
        version = "1.0.0";

        src = fetchHex {
          pkg = "bunt";
          version = "${version}";
          sha256 = "dc5f86aa08a5f6fa6b8096f0735c4e76d54ae5c9fa2c143e5a1fc7c1cd9bb6b5";
        };

        beamDeps = [ ];
      };

      bureaucrat = buildMix rec {
        name = "bureaucrat";
        version = "0.2.10";

        src = fetchHex {
          pkg = "bureaucrat";
          version = "${version}";
          sha256 = "bc7e5162b911c29c8ebefee87a2c16fbf13821a58f448a8fd024eb6c17fae15c";
        };

        beamDeps = [
          inflex
          phoenix
          plug
        ];
      };

      bypass = buildMix rec {
        name = "bypass";
        version = "2.1.0";

        src = fetchHex {
          pkg = "bypass";
          version = "${version}";
          sha256 = "d9b5df8fa5b7a6efa08384e9bbecfe4ce61c77d28a4282f79e02f1ef78d96b80";
        };

        beamDeps = [
          plug
          plug_cowboy
          ranch
        ];
      };

      castore = buildMix rec {
        name = "castore";
        version = "1.0.8";

        src = fetchHex {
          pkg = "castore";
          version = "${version}";
          sha256 = "0b2b66d2ee742cb1d9cb8c8be3b43c3a70ee8651f37b75a8b982e036752983f1";
        };

        beamDeps = [ ];
      };

      certifi = buildRebar3 rec {
        name = "certifi";
        version = "2.12.0";

        src = fetchHex {
          pkg = "certifi";
          version = "${version}";
          sha256 = "ee68d85df22e554040cdb4be100f33873ac6051387baf6a8f6ce82272340ff1c";
        };

        beamDeps = [ ];
      };

      chatterbox = buildRebar3 rec {
        name = "chatterbox";
        version = "0.15.1";

        src = fetchHex {
          pkg = "ts_chatterbox";
          version = "${version}";
          sha256 = "4f75b91451338bc0da5f52f3480fa6ef6e3a2aeecfc33686d6b3d0a0948f31aa";
        };

        beamDeps = [ hpack ];
      };

      cldr_utils = buildMix rec {
        name = "cldr_utils";
        version = "2.28.2";

        src = fetchHex {
          pkg = "cldr_utils";
          version = "${version}";
          sha256 = "c506eb1a170ba7cdca59b304ba02a56795ed119856662f6b1a420af80ec42551";
        };

        beamDeps = [
          castore
          certifi
          decimal
        ];
      };

      combine = buildMix rec {
        name = "combine";
        version = "0.10.0";

        src = fetchHex {
          pkg = "combine";
          version = "${version}";
          sha256 = "1b1dbc1790073076580d0d1d64e42eae2366583e7aecd455d1215b0d16f2451b";
        };

        beamDeps = [ ];
      };

      comeonin = buildMix rec {
        name = "comeonin";
        version = "5.4.0";

        src = fetchHex {
          pkg = "comeonin";
          version = "${version}";
          sha256 = "796393a9e50d01999d56b7b8420ab0481a7538d0caf80919da493b4a6e51faf1";
        };

        beamDeps = [ ];
      };

      cowboy = buildErlangMk rec {
        name = "cowboy";
        version = "2.12.0";

        src = fetchHex {
          pkg = "cowboy";
          version = "${version}";
          sha256 = "8a7abe6d183372ceb21caa2709bec928ab2b72e18a3911aa1771639bef82651e";
        };

        beamDeps = [
          cowlib
          ranch
        ];
      };

      cowboy_telemetry = buildRebar3 rec {
        name = "cowboy_telemetry";
        version = "0.4.0";

        src = fetchHex {
          pkg = "cowboy_telemetry";
          version = "${version}";
          sha256 = "7d98bac1ee4565d31b62d59f8823dfd8356a169e7fcbb83831b8a5397404c9de";
        };

        beamDeps = [
          cowboy
          telemetry
        ];
      };

      cowlib = buildRebar3 rec {
        name = "cowlib";
        version = "2.13.0";

        src = fetchHex {
          pkg = "cowlib";
          version = "${version}";
          sha256 = "e1e1284dc3fc030a64b1ad0d8382ae7e99da46c3246b815318a4b848873800a4";
        };

        beamDeps = [ ];
      };

      credo = buildMix rec {
        name = "credo";
        version = "1.7.7";

        src = fetchHex {
          pkg = "credo";
          version = "${version}";
          sha256 = "8bc87496c9aaacdc3f90f01b7b0582467b69b4bd2441fe8aae3109d843cc2f2e";
        };

        beamDeps = [
          bunt
          file_system
          jason
        ];
      };

      ctx = buildRebar3 rec {
        name = "ctx";
        version = "0.6.0";

        src = fetchHex {
          pkg = "ctx";
          version = "${version}";
          sha256 = "a14ed2d1b67723dbebbe423b28d7615eb0bdcba6ff28f2d1f1b0a7e1d4aa5fc2";
        };

        beamDeps = [ ];
      };

      db_connection = buildMix rec {
        name = "db_connection";
        version = "2.7.0";

        src = fetchHex {
          pkg = "db_connection";
          version = "${version}";
          sha256 = "dcf08f31b2701f857dfc787fbad78223d61a32204f217f15e881dd93e4bdd3ff";
        };

        beamDeps = [ telemetry ];
      };

      decimal = buildMix rec {
        name = "decimal";
        version = "2.3.0";

        src = fetchHex {
          pkg = "decimal";
          version = "${version}";
          sha256 = "a4d66355cb29cb47c3cf30e71329e58361cfcb37c34235ef3bf1d7bf3773aeac";
        };

        beamDeps = [ ];
      };

      dialyxir = buildMix rec {
        name = "dialyxir";
        version = "1.4.5";

        src = fetchHex {
          pkg = "dialyxir";
          version = "${version}";
          sha256 = "b0fb08bb8107c750db5c0b324fa2df5ceaa0f9307690ee3c1f6ba5b9eb5d35c3";
        };

        beamDeps = [ erlex ];
      };

      digital_token = buildMix rec {
        name = "digital_token";
        version = "1.0.0";

        src = fetchHex {
          pkg = "digital_token";
          version = "${version}";
          sha256 = "8ed6f5a8c2fa7b07147b9963db506a1b4c7475d9afca6492136535b064c9e9e6";
        };

        beamDeps = [
          cldr_utils
          jason
        ];
      };

      ecto = buildMix rec {
        name = "ecto";
        version = "3.12.5";

        src = fetchHex {
          pkg = "ecto";
          version = "${version}";
          sha256 = "6eb18e80bef8bb57e17f5a7f068a1719fbda384d40fc37acb8eb8aeca493b6ea";
        };

        beamDeps = [
          decimal
          jason
          telemetry
        ];
      };

      ecto_sql = buildMix rec {
        name = "ecto_sql";
        version = "3.12.0";

        src = fetchHex {
          pkg = "ecto_sql";
          version = "${version}";
          sha256 = "dc9e4d206f274f3947e96142a8fdc5f69a2a6a9abb4649ef5c882323b6d512f0";
        };

        beamDeps = [
          db_connection
          ecto
          postgrex
          telemetry
        ];
      };

      elixir_make = buildMix rec {
        name = "elixir_make";
        version = "0.8.4";

        src = fetchHex {
          pkg = "elixir_make";
          version = "${version}";
          sha256 = "6e7f1d619b5f61dfabd0a20aa268e575572b542ac31723293a4c1a567d5ef040";
        };

        beamDeps = [
          castore
          certifi
        ];
      };

      erlex = buildMix rec {
        name = "erlex";
        version = "0.2.7";

        src = fetchHex {
          pkg = "erlex";
          version = "${version}";
          sha256 = "3ed95f79d1a844c3f6bf0cea61e0d5612a42ce56da9c03f01df538685365efb0";
        };

        beamDeps = [ ];
      };

      esbuild = buildMix rec {
        name = "esbuild";
        version = "0.8.1";

        src = fetchHex {
          pkg = "esbuild";
          version = "${version}";
          sha256 = "25fc876a67c13cb0a776e7b5d7974851556baeda2085296c14ab48555ea7560f";
        };

        beamDeps = [
          castore
          jason
        ];
      };

      ex_cldr = buildMix rec {
        name = "ex_cldr";
        version = "2.40.1";

        src = fetchHex {
          pkg = "ex_cldr";
          version = "${version}";
          sha256 = "509810702e8e81991851d9426ffe6b34b48b7b9baa12922e7b3fb8f6368606f3";
        };

        beamDeps = [
          cldr_utils
          decimal
          gettext
          jason
        ];
      };

      ex_cldr_calendars = buildMix rec {
        name = "ex_cldr_calendars";
        version = "1.26.2";

        src = fetchHex {
          pkg = "ex_cldr_calendars";
          version = "${version}";
          sha256 = "b689847f3fbbd145954a9205e19b1e4850a79c2a27cdae1c7912b9b262a8ef35";
        };

        beamDeps = [
          ex_cldr_numbers
          jason
        ];
      };

      ex_cldr_currencies = buildMix rec {
        name = "ex_cldr_currencies";
        version = "2.16.3";

        src = fetchHex {
          pkg = "ex_cldr_currencies";
          version = "${version}";
          sha256 = "4d1b5f8449fdf0ece6a2e5c7401ad8fcfde77ee6ea480bddc16e266dfa2b570c";
        };

        beamDeps = [
          ex_cldr
          jason
        ];
      };

      ex_cldr_dates_times = buildMix rec {
        name = "ex_cldr_dates_times";
        version = "2.20.3";

        src = fetchHex {
          pkg = "ex_cldr_dates_times";
          version = "${version}";
          sha256 = "52fe1493f44d2420d4af80dbafb65c89bfd17f0758a98c4ad61182518bb6e5a1";
        };

        beamDeps = [
          ex_cldr
          ex_cldr_calendars
          jason
        ];
      };

      ex_cldr_numbers = buildMix rec {
        name = "ex_cldr_numbers";
        version = "2.33.3";

        src = fetchHex {
          pkg = "ex_cldr_numbers";
          version = "${version}";
          sha256 = "4a0d90d06710c1499528d5f536c539379a73a68d4679c55375198a798d138442";
        };

        beamDeps = [
          decimal
          digital_token
          ex_cldr
          ex_cldr_currencies
          jason
        ];
      };

      expo = buildMix rec {
        name = "expo";
        version = "1.1.0";

        src = fetchHex {
          pkg = "expo";
          version = "${version}";
          sha256 = "fbadf93f4700fb44c331362177bdca9eeb8097e8b0ef525c9cc501cb9917c960";
        };

        beamDeps = [ ];
      };

      file_size = buildMix rec {
        name = "file_size";
        version = "3.0.1";

        src = fetchHex {
          pkg = "file_size";
          version = "${version}";
          sha256 = "64dd665bc37920480c249785788265f5d42e98830d757c6a477b3246703b8e20";
        };

        beamDeps = [
          decimal
          number
        ];
      };

      file_system = buildMix rec {
        name = "file_system";
        version = "1.0.1";

        src = fetchHex {
          pkg = "file_system";
          version = "${version}";
          sha256 = "4414d1f38863ddf9120720cd976fce5bdde8e91d8283353f0e31850fa89feb9e";
        };

        beamDeps = [ ];
      };

      finch = buildMix rec {
        name = "finch";
        version = "0.19.0";

        src = fetchHex {
          pkg = "finch";
          version = "${version}";
          sha256 = "fc5324ce209125d1e2fa0fcd2634601c52a787aff1cd33ee833664a5af4ea2b6";
        };

        beamDeps = [
          mime
          mint
          nimble_options
          nimble_pool
          telemetry
        ];
      };

      floki = buildMix rec {
        name = "floki";
        version = "0.37.0";

        src = fetchHex {
          pkg = "floki";
          version = "${version}";
          sha256 = "516a0c15a69f78c47dc8e0b9b3724b29608aa6619379f91b1ffa47109b5d0dd3";
        };

        beamDeps = [ ];
      };

      gen_smtp = buildRebar3 rec {
        name = "gen_smtp";
        version = "1.2.0";

        src = fetchHex {
          pkg = "gen_smtp";
          version = "${version}";
          sha256 = "5ee0375680bca8f20c4d85f58c2894441443a743355430ff33a783fe03296779";
        };

        beamDeps = [ ranch ];
      };

      gettext = buildMix rec {
        name = "gettext";
        version = "0.26.1";

        src = fetchHex {
          pkg = "gettext";
          version = "${version}";
          sha256 = "01ce56f188b9dc28780a52783d6529ad2bc7124f9744e571e1ee4ea88bf08734";
        };

        beamDeps = [ expo ];
      };

      gproc = buildRebar3 rec {
        name = "gproc";
        version = "0.9.1";

        src = fetchHex {
          pkg = "gproc";
          version = "${version}";
          sha256 = "905088e32e72127ed9466f0bac0d8e65704ca5e73ee5a62cb073c3117916d507";
        };

        beamDeps = [ ];
      };

      grpcbox = buildRebar3 rec {
        name = "grpcbox";
        version = "0.17.1";

        src = fetchHex {
          pkg = "grpcbox";
          version = "${version}";
          sha256 = "4a3b5d7111daabc569dc9cbd9b202a3237d81c80bf97212fbc676832cb0ceb17";
        };

        beamDeps = [
          acceptor_pool
          chatterbox
          ctx
          gproc
        ];
      };

      hackney = buildRebar3 rec {
        name = "hackney";
        version = "1.20.1";

        src = fetchHex {
          pkg = "hackney";
          version = "${version}";
          sha256 = "fe9094e5f1a2a2c0a7d10918fee36bfec0ec2a979994cff8cfe8058cd9af38e3";
        };

        beamDeps = [
          certifi
          idna
          metrics
          mimerl
          parse_trans
          ssl_verify_fun
          unicode_util_compat
        ];
      };

      hpack = buildRebar3 rec {
        name = "hpack";
        version = "0.3.0";

        src = fetchHex {
          pkg = "hpack_erl";
          version = "${version}";
          sha256 = "d6137d7079169d8c485c6962dfe261af5b9ef60fbc557344511c1e65e3d95fb0";
        };

        beamDeps = [ ];
      };

      hpax = buildMix rec {
        name = "hpax";
        version = "1.0.0";

        src = fetchHex {
          pkg = "hpax";
          version = "${version}";
          sha256 = "7f1314731d711e2ca5fdc7fd361296593fc2542570b3105595bb0bc6d0fad601";
        };

        beamDeps = [ ];
      };

      httpoison = buildMix rec {
        name = "httpoison";
        version = "2.2.1";

        src = fetchHex {
          pkg = "httpoison";
          version = "${version}";
          sha256 = "51364e6d2f429d80e14fe4b5f8e39719cacd03eb3f9a9286e61e216feac2d2df";
        };

        beamDeps = [ hackney ];
      };

      idna = buildRebar3 rec {
        name = "idna";
        version = "6.1.1";

        src = fetchHex {
          pkg = "idna";
          version = "${version}";
          sha256 = "92376eb7894412ed19ac475e4a86f7b413c1b9fbb5bd16dccd57934157944cea";
        };

        beamDeps = [ unicode_util_compat ];
      };

      inflex = buildMix rec {
        name = "inflex";
        version = "2.1.0";

        src = fetchHex {
          pkg = "inflex";
          version = "${version}";
          sha256 = "14c17d05db4ee9b6d319b0bff1bdf22aa389a25398d1952c7a0b5f3d93162dd8";
        };

        beamDeps = [ ];
      };

      jason = buildMix rec {
        name = "jason";
        version = "1.4.4";

        src = fetchHex {
          pkg = "jason";
          version = "${version}";
          sha256 = "c5eb0cab91f094599f94d55bc63409236a8ec69a21a67814529e8d5f6cc90b3b";
        };

        beamDeps = [ decimal ];
      };

      jose = buildMix rec {
        name = "jose";
        version = "1.11.10";

        src = fetchHex {
          pkg = "jose";
          version = "${version}";
          sha256 = "0d6cd36ff8ba174db29148fc112b5842186b68a90ce9fc2b3ec3afe76593e614";
        };

        beamDeps = [ ];
      };

      junit_formatter = buildMix rec {
        name = "junit_formatter";
        version = "3.4.0";

        src = fetchHex {
          pkg = "junit_formatter";
          version = "${version}";
          sha256 = "bb36e2ae83f1ced6ab931c4ce51dd3dbef1ef61bb4932412e173b0cfa259dacd";
        };

        beamDeps = [ ];
      };

      libcluster = buildMix rec {
        name = "libcluster";
        version = "3.3.3";

        src = fetchHex {
          pkg = "libcluster";
          version = "${version}";
          sha256 = "7c0a2275a0bb83c07acd17dab3c3bfb4897b145106750eeccc62d302e3bdfee5";
        };

        beamDeps = [ jason ];
      };

      logger_json = buildMix rec {
        name = "logger_json";
        version = "6.2.0";

        src = fetchHex {
          pkg = "logger_json";
          version = "${version}";
          sha256 = "98366d02bedbb56e41b25a6d248d566d4f4bc224bae2b1e982df00ed04ba9219";
        };

        beamDeps = [
          ecto
          jason
          plug
          telemetry
        ];
      };

      mail = buildMix rec {
        name = "mail";
        version = "0.3.1";

        src = fetchHex {
          pkg = "mail";
          version = "${version}";
          sha256 = "1db701e89865c1d5fa296b2b57b1cd587587cca8d8a1a22892b35ef5a8e352a6";
        };

        beamDeps = [ ];
      };

      metrics = buildRebar3 rec {
        name = "metrics";
        version = "1.0.1";

        src = fetchHex {
          pkg = "metrics";
          version = "${version}";
          sha256 = "69b09adddc4f74a40716ae54d140f93beb0fb8978d8636eaded0c31b6f099f16";
        };

        beamDeps = [ ];
      };

      mime = buildMix rec {
        name = "mime";
        version = "2.0.6";

        src = fetchHex {
          pkg = "mime";
          version = "${version}";
          sha256 = "c9945363a6b26d747389aac3643f8e0e09d30499a138ad64fe8fd1d13d9b153e";
        };

        beamDeps = [ ];
      };

      mimerl = buildRebar3 rec {
        name = "mimerl";
        version = "1.3.0";

        src = fetchHex {
          pkg = "mimerl";
          version = "${version}";
          sha256 = "a1e15a50d1887217de95f0b9b0793e32853f7c258a5cd227650889b38839fe9d";
        };

        beamDeps = [ ];
      };

      mint = buildMix rec {
        name = "mint";
        version = "1.6.2";

        src = fetchHex {
          pkg = "mint";
          version = "${version}";
          sha256 = "5ee441dffc1892f1ae59127f74afe8fd82fda6587794278d924e4d90ea3d63f9";
        };

        beamDeps = [
          castore
          hpax
        ];
      };

      mix_audit = buildMix rec {
        name = "mix_audit";
        version = "2.1.4";

        src = fetchHex {
          pkg = "mix_audit";
          version = "${version}";
          sha256 = "fd807653cc8c1cada2911129c7eb9e985e3cc76ebf26f4dd628bb25bbcaa7099";
        };

        beamDeps = [
          jason
          yaml_elixir
        ];
      };

      mua = buildMix rec {
        name = "mua";
        version = "0.2.4";

        src = fetchHex {
          pkg = "mua";
          version = "${version}";
          sha256 = "e7e4dacd5ad65f13e3542772e74a159c00bd2d5579e729e9bb72d2c73a266fb7";
        };

        beamDeps = [ castore ];
      };

      multipart = buildMix rec {
        name = "multipart";
        version = "0.4.0";

        src = fetchHex {
          pkg = "multipart";
          version = "${version}";
          sha256 = "3c5604bc2fb17b3137e5d2abdf5dacc2647e60c5cc6634b102cf1aef75a06f0a";
        };

        beamDeps = [ mime ];
      };

      nimble_csv = buildMix rec {
        name = "nimble_csv";
        version = "1.2.0";

        src = fetchHex {
          pkg = "nimble_csv";
          version = "${version}";
          sha256 = "d0628117fcc2148178b034044c55359b26966c6eaa8e2ce15777be3bbc91b12a";
        };

        beamDeps = [ ];
      };

      nimble_options = buildMix rec {
        name = "nimble_options";
        version = "1.1.1";

        src = fetchHex {
          pkg = "nimble_options";
          version = "${version}";
          sha256 = "821b2470ca9442c4b6984882fe9bb0389371b8ddec4d45a9504f00a66f650b44";
        };

        beamDeps = [ ];
      };

      nimble_pool = buildMix rec {
        name = "nimble_pool";
        version = "1.1.0";

        src = fetchHex {
          pkg = "nimble_pool";
          version = "${version}";
          sha256 = "af2e4e6b34197db81f7aad230c1118eac993acc0dae6bc83bac0126d4ae0813a";
        };

        beamDeps = [ ];
      };

      number = buildMix rec {
        name = "number";
        version = "1.0.5";

        src = fetchHex {
          pkg = "number";
          version = "${version}";
          sha256 = "c0733a0a90773a66582b9e92a3f01290987f395c972cb7d685f51dd927cd5169";
        };

        beamDeps = [ decimal ];
      };

      observer_cli = buildMix rec {
        name = "observer_cli";
        version = "1.7.5";

        src = fetchHex {
          pkg = "observer_cli";
          version = "${version}";
          sha256 = "872cf8e833a3a71ebd05420692678ec8aaede8fd96c805a4687398f6b23a3014";
        };

        beamDeps = [ recon ];
      };

      open_api_spex = buildMix rec {
        name = "open_api_spex";
        version = "3.21.2";

        src = fetchHex {
          pkg = "open_api_spex";
          version = "${version}";
          sha256 = "f42ae6ed668b895ebba3e02773cfb4b41050df26f803f2ef634c72a7687dc387";
        };

        beamDeps = [
          decimal
          jason
          plug
          ymlr
        ];
      };

      opentelemetry = buildRebar3 rec {
        name = "opentelemetry";
        version = "1.5.0";

        src = fetchHex {
          pkg = "opentelemetry";
          version = "${version}";
          sha256 = "cdf4f51d17b592fc592b9a75f86a6f808c23044ba7cf7b9534debbcc5c23b0ee";
        };

        beamDeps = [ opentelemetry_api ];
      };

      opentelemetry_api = buildMix rec {
        name = "opentelemetry_api";
        version = "1.4.0";

        src = fetchHex {
          pkg = "opentelemetry_api";
          version = "${version}";
          sha256 = "3dfbbfaa2c2ed3121c5c483162836c4f9027def469c41578af5ef32589fcfc58";
        };

        beamDeps = [ ];
      };

      opentelemetry_cowboy = buildRebar3 rec {
        name = "opentelemetry_cowboy";
        version = "1.0.0";

        src = fetchHex {
          pkg = "opentelemetry_cowboy";
          version = "${version}";
          sha256 = "7575716eaccacd0eddc3e7e61403aecb5d0a6397183987d6049094aeb0b87a7c";
        };

        beamDeps = [
          cowboy_telemetry
          opentelemetry_api
          opentelemetry_semantic_conventions
          opentelemetry_telemetry
          otel_http
          telemetry
        ];
      };

      opentelemetry_ecto = buildMix rec {
        name = "opentelemetry_ecto";
        version = "1.2.0";

        src = fetchHex {
          pkg = "opentelemetry_ecto";
          version = "${version}";
          sha256 = "70dfa2e79932e86f209df00e36c980b17a32f82d175f0068bf7ef9a96cf080cf";
        };

        beamDeps = [
          opentelemetry_api
          opentelemetry_process_propagator
          telemetry
        ];
      };

      opentelemetry_exporter = buildRebar3 rec {
        name = "opentelemetry_exporter";
        version = "1.8.0";

        src = fetchHex {
          pkg = "opentelemetry_exporter";
          version = "${version}";
          sha256 = "a1f9f271f8d3b02b81462a6bfef7075fd8457fdb06adff5d2537df5e2264d9af";
        };

        beamDeps = [
          grpcbox
          opentelemetry
          opentelemetry_api
          tls_certificate_check
        ];
      };

      opentelemetry_finch = buildMix rec {
        name = "opentelemetry_finch";
        version = "0.2.0";

        src = fetchHex {
          pkg = "opentelemetry_finch";
          version = "${version}";
          sha256 = "7364f70822ec282853cade12953f40d7b94e03967608a52fd406e3b080f18d5e";
        };

        beamDeps = [
          opentelemetry_api
          telemetry
        ];
      };

      opentelemetry_liveview = buildMix rec {
        name = "opentelemetry_liveview";
        version = "1.0.0-rc.4";

        src = fetchHex {
          pkg = "opentelemetry_liveview";
          version = "${version}";
          sha256 = "e06ab69da7ee46158342cac42f1c22886bdeab53e8d8c4e237c3b3c2cf7b815d";
        };

        beamDeps = [
          opentelemetry_api
          opentelemetry_telemetry
          telemetry
        ];
      };

      opentelemetry_logger_metadata = buildMix rec {
        name = "opentelemetry_logger_metadata";
        version = "0.1.0";

        src = fetchHex {
          pkg = "opentelemetry_logger_metadata";
          version = "${version}";
          sha256 = "772976d3c59651cf9c4600edc238bb9cadf7f5edaed1a1c5c59bf3e773dfe9fc";
        };

        beamDeps = [ opentelemetry_api ];
      };

      opentelemetry_phoenix = buildMix rec {
        name = "opentelemetry_phoenix";
        version = "2.0.0";

        src = fetchHex {
          pkg = "opentelemetry_phoenix";
          version = "${version}";
          sha256 = "c2c0969c561a87703cda64e9f0c37e9dec6dceee11c2d2eafef8d3f4138ec364";
        };

        beamDeps = [
          nimble_options
          opentelemetry_api
          opentelemetry_process_propagator
          opentelemetry_semantic_conventions
          opentelemetry_telemetry
          otel_http
          plug
          telemetry
        ];
      };

      opentelemetry_process_propagator = buildMix rec {
        name = "opentelemetry_process_propagator";
        version = "0.3.0";

        src = fetchHex {
          pkg = "opentelemetry_process_propagator";
          version = "${version}";
          sha256 = "7243cb6de1523c473cba5b1aefa3f85e1ff8cc75d08f367104c1e11919c8c029";
        };

        beamDeps = [ opentelemetry_api ];
      };

      opentelemetry_semantic_conventions = buildMix rec {
        name = "opentelemetry_semantic_conventions";
        version = "1.27.0";

        src = fetchHex {
          pkg = "opentelemetry_semantic_conventions";
          version = "${version}";
          sha256 = "9681ccaa24fd3d810b4461581717661fd85ff7019b082c2dff89c7d5b1fc2864";
        };

        beamDeps = [ ];
      };

      opentelemetry_telemetry = buildMix rec {
        name = "opentelemetry_telemetry";
        version = "1.1.2";

        src = fetchHex {
          pkg = "opentelemetry_telemetry";
          version = "${version}";
          sha256 = "641ab469deb181957ac6d59bce6e1321d5fe2a56df444fc9c19afcad623ab253";
        };

        beamDeps = [
          opentelemetry_api
          telemetry
        ];
      };

      otel_http = buildRebar3 rec {
        name = "otel_http";
        version = "0.2.0";

        src = fetchHex {
          pkg = "otel_http";
          version = "${version}";
          sha256 = "f2beadf922c8cfeb0965488dd736c95cc6ea8b9efce89466b3904d317d7cc717";
        };

        beamDeps = [ ];
      };

      parse_trans = buildRebar3 rec {
        name = "parse_trans";
        version = "3.4.1";

        src = fetchHex {
          pkg = "parse_trans";
          version = "${version}";
          sha256 = "620a406ce75dada827b82e453c19cf06776be266f5a67cff34e1ef2cbb60e49a";
        };

        beamDeps = [ ];
      };

      phoenix = buildMix rec {
        name = "phoenix";
        version = "1.7.14";

        src = fetchHex {
          pkg = "phoenix";
          version = "${version}";
          sha256 = "c7859bc56cc5dfef19ecfc240775dae358cbaa530231118a9e014df392ace61a";
        };

        beamDeps = [
          castore
          jason
          phoenix_pubsub
          phoenix_template
          phoenix_view
          plug
          plug_cowboy
          plug_crypto
          telemetry
          websock_adapter
        ];
      };

      phoenix_ecto = buildMix rec {
        name = "phoenix_ecto";
        version = "4.6.3";

        src = fetchHex {
          pkg = "phoenix_ecto";
          version = "${version}";
          sha256 = "909502956916a657a197f94cc1206d9a65247538de8a5e186f7537c895d95764";
        };

        beamDeps = [
          ecto
          phoenix_html
          plug
          postgrex
        ];
      };

      phoenix_html = buildMix rec {
        name = "phoenix_html";
        version = "4.2.0";

        src = fetchHex {
          pkg = "phoenix_html";
          version = "${version}";
          sha256 = "9713b3f238d07043583a94296cc4bbdceacd3b3a6c74667f4df13971e7866ec8";
        };

        beamDeps = [ ];
      };

      phoenix_live_reload = buildMix rec {
        name = "phoenix_live_reload";
        version = "1.5.3";

        src = fetchHex {
          pkg = "phoenix_live_reload";
          version = "${version}";
          sha256 = "b4ec9cd73cb01ff1bd1cac92e045d13e7030330b74164297d1aee3907b54803c";
        };

        beamDeps = [
          file_system
          phoenix
        ];
      };

      phoenix_live_view = buildMix rec {
        name = "phoenix_live_view";
        version = "1.0.0-rc.6";

        src = fetchHex {
          pkg = "phoenix_live_view";
          version = "${version}";
          sha256 = "e56e4f1642a0b20edc2488cab30e5439595e0d8b5b259f76ef98b1c4e2e5b527";
        };

        beamDeps = [
          floki
          jason
          phoenix
          phoenix_html
          phoenix_template
          phoenix_view
          plug
          telemetry
        ];
      };

      phoenix_pubsub = buildMix rec {
        name = "phoenix_pubsub";
        version = "2.1.3";

        src = fetchHex {
          pkg = "phoenix_pubsub";
          version = "${version}";
          sha256 = "bba06bc1dcfd8cb086759f0edc94a8ba2bc8896d5331a1e2c2902bf8e36ee502";
        };

        beamDeps = [ ];
      };

      phoenix_swoosh = buildMix rec {
        name = "phoenix_swoosh";
        version = "1.2.1";

        src = fetchHex {
          pkg = "phoenix_swoosh";
          version = "${version}";
          sha256 = "4000eeba3f9d7d1a6bf56d2bd56733d5cadf41a7f0d8ffe5bb67e7d667e204a2";
        };

        beamDeps = [
          finch
          hackney
          phoenix
          phoenix_html
          phoenix_view
          swoosh
        ];
      };

      phoenix_template = buildMix rec {
        name = "phoenix_template";
        version = "1.0.4";

        src = fetchHex {
          pkg = "phoenix_template";
          version = "${version}";
          sha256 = "2c0c81f0e5c6753faf5cca2f229c9709919aba34fab866d3bc05060c9c444206";
        };

        beamDeps = [ phoenix_html ];
      };

      phoenix_view = buildMix rec {
        name = "phoenix_view";
        version = "2.0.4";

        src = fetchHex {
          pkg = "phoenix_view";
          version = "${version}";
          sha256 = "4e992022ce14f31fe57335db27a28154afcc94e9983266835bb3040243eb620b";
        };

        beamDeps = [
          phoenix_html
          phoenix_template
        ];
      };

      plug = buildMix rec {
        name = "plug";
        version = "1.16.1";

        src = fetchHex {
          pkg = "plug";
          version = "${version}";
          sha256 = "a13ff6b9006b03d7e33874945b2755253841b238c34071ed85b0e86057f8cddc";
        };

        beamDeps = [
          mime
          plug_crypto
          telemetry
        ];
      };

      plug_cowboy = buildMix rec {
        name = "plug_cowboy";
        version = "2.7.2";

        src = fetchHex {
          pkg = "plug_cowboy";
          version = "${version}";
          sha256 = "245d8a11ee2306094840c000e8816f0cbed69a23fc0ac2bcf8d7835ae019bb2f";
        };

        beamDeps = [
          cowboy
          cowboy_telemetry
          plug
        ];
      };

      plug_crypto = buildMix rec {
        name = "plug_crypto";
        version = "2.1.0";

        src = fetchHex {
          pkg = "plug_crypto";
          version = "${version}";
          sha256 = "131216a4b030b8f8ce0f26038bc4421ae60e4bb95c5cf5395e1421437824c4fa";
        };

        beamDeps = [ ];
      };

      postgrex = buildMix rec {
        name = "postgrex";
        version = "0.19.3";

        src = fetchHex {
          pkg = "postgrex";
          version = "${version}";
          sha256 = "d31c28053655b78f47f948c85bb1cf86a9c1f8ead346ba1aa0d0df017fa05b61";
        };

        beamDeps = [
          db_connection
          decimal
          jason
        ];
      };

      ranch = buildRebar3 rec {
        name = "ranch";
        version = "1.8.0";

        src = fetchHex {
          pkg = "ranch";
          version = "${version}";
          sha256 = "49fbcfd3682fab1f5d109351b61257676da1a2fdbe295904176d5e521a2ddfe5";
        };

        beamDeps = [ ];
      };

      recon = buildMix rec {
        name = "recon";
        version = "2.5.6";

        src = fetchHex {
          pkg = "recon";
          version = "${version}";
          sha256 = "96c6799792d735cc0f0fd0f86267e9d351e63339cbe03df9d162010cefc26bb0";
        };

        beamDeps = [ ];
      };

      remote_ip = buildMix rec {
        name = "remote_ip";
        version = "1.2.0";

        src = fetchHex {
          pkg = "remote_ip";
          version = "${version}";
          sha256 = "2ff91de19c48149ce19ed230a81d377186e4412552a597d6a5137373e5877cb7";
        };

        beamDeps = [
          combine
          plug
        ];
      };

      sizeable = buildMix rec {
        name = "sizeable";
        version = "1.0.2";

        src = fetchHex {
          pkg = "sizeable";
          version = "${version}";
          sha256 = "4bab548e6dfba777b400ca50830a9e3a4128e73df77ab1582540cf5860601762";
        };

        beamDeps = [ ];
      };

      sobelow = buildMix rec {
        name = "sobelow";
        version = "0.13.0";

        src = fetchHex {
          pkg = "sobelow";
          version = "${version}";
          sha256 = "cd6e9026b85fc35d7529da14f95e85a078d9dd1907a9097b3ba6ac7ebbe34a0d";
        };

        beamDeps = [ jason ];
      };

      ssl_verify_fun = buildRebar3 rec {
        name = "ssl_verify_fun";
        version = "1.1.7";

        src = fetchHex {
          pkg = "ssl_verify_fun";
          version = "${version}";
          sha256 = "fe4c190e8f37401d30167c8c405eda19469f34577987c76dde613e838bbc67f8";
        };

        beamDeps = [ ];
      };

      swoosh = buildMix rec {
        name = "swoosh";
        version = "1.17.0";

        src = fetchHex {
          pkg = "swoosh";
          version = "${version}";
          sha256 = "659b8bc25f7483b872d051a7f0731fb8d5312165be0d0302a3c783b566b0a290";
        };

        beamDeps = [
          bandit
          cowboy
          finch
          gen_smtp
          hackney
          jason
          mail
          mime
          mua
          multipart
          plug
          plug_cowboy
          telemetry
        ];
      };

      tailwind = buildMix rec {
        name = "tailwind";
        version = "0.2.3";

        src = fetchHex {
          pkg = "tailwind";
          version = "${version}";
          sha256 = "8e45e7a34a676a7747d04f7913a96c770c85e6be810a1d7f91e713d3a3655b5d";
        };

        beamDeps = [ castore ];
      };

      telemetry = buildRebar3 rec {
        name = "telemetry";
        version = "1.3.0";

        src = fetchHex {
          pkg = "telemetry";
          version = "${version}";
          sha256 = "7015fc8919dbe63764f4b4b87a95b7c0996bd539e0d499be6ec9d7f3875b79e6";
        };

        beamDeps = [ ];
      };

      telemetry_metrics = buildMix rec {
        name = "telemetry_metrics";
        version = "1.0.0";

        src = fetchHex {
          pkg = "telemetry_metrics";
          version = "${version}";
          sha256 = "f23713b3847286a534e005126d4c959ebcca68ae9582118ce436b521d1d47d5d";
        };

        beamDeps = [ telemetry ];
      };

      telemetry_poller = buildRebar3 rec {
        name = "telemetry_poller";
        version = "1.1.0";

        src = fetchHex {
          pkg = "telemetry_poller";
          version = "${version}";
          sha256 = "9eb9d9cbfd81cbd7cdd24682f8711b6e2b691289a0de6826e58452f28c103c8f";
        };

        beamDeps = [ telemetry ];
      };

      tesla = buildMix rec {
        name = "tesla";
        version = "1.12.1";

        src = fetchHex {
          pkg = "tesla";
          version = "${version}";
          sha256 = "2391efc6243d37ead43afd0327b520314c7b38232091d4a440c1212626fdd6e7";
        };

        beamDeps = [
          castore
          finch
          hackney
          jason
          mime
          mint
          telemetry
        ];
      };

      thousand_island = buildMix rec {
        name = "thousand_island";
        version = "1.3.5";

        src = fetchHex {
          pkg = "thousand_island";
          version = "${version}";
          sha256 = "2be6954916fdfe4756af3239fb6b6d75d0b8063b5df03ba76fd8a4c87849e180";
        };

        beamDeps = [ telemetry ];
      };

      tls_certificate_check = buildRebar3 rec {
        name = "tls_certificate_check";
        version = "1.26.0";

        src = fetchHex {
          pkg = "tls_certificate_check";
          version = "${version}";
          sha256 = "1bad73d88637f788b554a8e939c25db2bdaac88b10fffd5bba9d1b65f43a6b54";
        };

        beamDeps = [ ssl_verify_fun ];
      };

      tzdata = buildMix rec {
        name = "tzdata";
        version = "1.1.2";

        src = fetchHex {
          pkg = "tzdata";
          version = "${version}";
          sha256 = "cec7b286e608371602318c414f344941d5eb0375e14cfdab605cca2fe66cba8b";
        };

        beamDeps = [ hackney ];
      };

      unicode_util_compat = buildRebar3 rec {
        name = "unicode_util_compat";
        version = "0.7.0";

        src = fetchHex {
          pkg = "unicode_util_compat";
          version = "${version}";
          sha256 = "25eee6d67df61960cf6a794239566599b09e17e668d3700247bc498638152521";
        };

        beamDeps = [ ];
      };

      wallaby = buildMix rec {
        name = "wallaby";
        version = "0.30.9";

        src = fetchHex {
          pkg = "wallaby";
          version = "${version}";
          sha256 = "62e3ccb89068b231b50ed046219022020516d44f443eebef93a19db4be95b808";
        };

        beamDeps = [
          ecto_sql
          httpoison
          jason
          phoenix_ecto
          web_driver_client
        ];
      };

      web_driver_client = buildMix rec {
        name = "web_driver_client";
        version = "0.2.0";

        src = fetchHex {
          pkg = "web_driver_client";
          version = "${version}";
          sha256 = "83cc6092bc3e74926d1c8455f0ce927d5d1d36707b74d9a65e38c084aab0350f";
        };

        beamDeps = [
          hackney
          jason
          tesla
        ];
      };

      websock = buildMix rec {
        name = "websock";
        version = "0.5.3";

        src = fetchHex {
          pkg = "websock";
          version = "${version}";
          sha256 = "6105453d7fac22c712ad66fab1d45abdf049868f253cf719b625151460b8b453";
        };

        beamDeps = [ ];
      };

      websock_adapter = buildMix rec {
        name = "websock_adapter";
        version = "0.5.7";

        src = fetchHex {
          pkg = "websock_adapter";
          version = "${version}";
          sha256 = "d0f478ee64deddfec64b800673fd6e0c8888b079d9f3444dd96d2a98383bdbd1";
        };

        beamDeps = [
          bandit
          plug
          plug_cowboy
          websock
        ];
      };

      workos = buildMix rec {
        name = "workos";
        version = "1.1.0";

        src = fetchHex {
          pkg = "workos";
          version = "${version}";
          sha256 = "88034983748821353cc28660278e0fd1886378bd4888ea77651889c0d126f3d5";
        };

        beamDeps = [
          hackney
          jason
          plug_crypto
          tesla
        ];
      };

      yamerl = buildRebar3 rec {
        name = "yamerl";
        version = "0.10.0";

        src = fetchHex {
          pkg = "yamerl";
          version = "${version}";
          sha256 = "346adb2963f1051dc837a2364e4acf6eb7d80097c0f53cbdc3046ec8ec4b4e6e";
        };

        beamDeps = [ ];
      };

      yaml_elixir = buildMix rec {
        name = "yaml_elixir";
        version = "2.11.0";

        src = fetchHex {
          pkg = "yaml_elixir";
          version = "${version}";
          sha256 = "53cc28357ee7eb952344995787f4bb8cc3cecbf189652236e9b163e8ce1bc242";
        };

        beamDeps = [ yamerl ];
      };

      ymlr = buildMix rec {
        name = "ymlr";
        version = "5.1.3";

        src = fetchHex {
          pkg = "ymlr";
          version = "${version}";
          sha256 = "8663444fa85101a117887c170204d4c5a2182567e5f84767f0071cf15f2efb1e";
        };

        beamDeps = [ ];
      };
    };
in
self
