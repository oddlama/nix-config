_inputs: [
  (import ./scripts)
  (_final: prev: {
    deploy = prev.callPackage ./deploy.nix { };
    git-fuzzy = prev.callPackage ./git-fuzzy { };
    segoe-ui-ttf = prev.callPackage ./segoe-ui-ttf.nix { };
    zsh-histdb-skim = prev.callPackage ./zsh-skim-histdb.nix { };
    neovim-clean = prev.neovim-unwrapped.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.makeWrapper ];
      postInstall =
        (old.postInstall or "")
        + ''
          wrapProgram $out/bin/nvim --add-flags "--clean"
        '';
    });
    #pythonPackagesExtensions =
    #  prev.pythonPackagesExtensions
    #  ++ [
    #    (_pythonFinal: pythonPrev: {
    #    })
    #  ];

    firezone-server-api = prev.callPackage ../fz/pkgs/firezone-server/package.nix {
      mixReleaseName = "api";
    };

    firezone-server-domain = prev.callPackage ../fz/pkgs/firezone-server/package.nix {
      mixReleaseName = "domain";
    };

    firezone-server-web = prev.callPackage ../fz/pkgs/firezone-server/package.nix {
      mixReleaseName = "web";
    };

    firezone-gateway = prev.callPackage ../fz/pkgs/firezone-gateway/package.nix { };
    firezone-relay = prev.callPackage ../fz/pkgs/firezone-relay/package.nix { };
    firezone-gui-client = prev.callPackage ../fz/pkgs/firezone-gui-client/package.nix { };
    firezone-headless-client = prev.callPackage ../fz/pkgs/firezone-headless-client/package.nix { };

    mdns-repeater = prev.callPackage ./mdns-repeater.nix { };

    formats = prev.formats // {
      ron = import ./ron.nix { inherit (prev) lib pkgs; };
    };
  })
]
