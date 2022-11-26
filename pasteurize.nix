{
  nixpkgs,
  cellBlock,
}: let
  l = nixpkgs.lib // builtins;
  evalModulesMinimal =
    (import (nixpkgs + /nixos/lib/default.nix) {
      inherit (nixpkgs) lib;
      # don't show the warning.
      featureFlags.minimalModules = {};
    })
    .evalModules;

  beeOptions = {config, ...}: {
    options.bee = {
      system = l.mkOption {
        type = l.types.str;
        description = "divnix/hive requires you to set the host's system via 'config.bee.system = \"x86_64-linux\";'";
      };
      home = l.mkOption {
        type = l.mkOptionType {
          name = "input";
          description = "home-manager input";
          check = x: (l.isAttrs x) && (l.hasAttr "sourceInfo" x);
        };
        description = "divnix/hive requires you to set the home-manager input via 'config.bee.home = inputs.home-22-05;'";
      };
      pkgs = l.mkOption {
        type = l.mkOptionType {
          name = "packages";
          description = "instance of nixpkgs";
          check = x: (l.isAttrs x) && (l.hasAttr "path" x);
        };
        description = "divnix/hive requires you to set the nixpkgs instance via 'config.bee.pkgs = inputs.nixos-22.05.legacyPackages;'";
        apply = x:
          if (l.hasAttr "${config.bee.system}" x)
          then x.${config.bee.system}
          else x;
      };
    };
  };

  combCheckModule = let
    erase = optionName: {options, ...}: let
      opt = l.getAttrFromPath optionName options;
    in {
      options = l.setAttrByPath optionName (l.mkOption {visible = false;});
      config._hive_erased = [
        {
          assertion = !opt.isDefined;
          message = ''
            The option definition `${l.showOption optionName}' in ${l.showFiles opt.files}  is not supported by divnix/hive.

            This is a Standard simplification.

              - Please set 'config.bee.pkgs' to an instantiated version of nixpkgs.
              - Also declare the host system via 'config.bee.system'.
          '';
        }
      ];
    };
  in
    {config, ...}: {
      imports = [
        (erase ["nixpkgs" "config"])
        (erase ["nixpkgs" "overlays"])
        (erase ["nixpkgs" "system"])
        (erase ["nixpkgs" "localSystem"])
        (erase ["nixpkgs" "crossSystem"])
        (erase ["nixpkgs" "pkgs"])
      ];
      config._module = {
        freeformType = l.types.unspecified;
        check = true;
      };
      options._hive_erased = l.mkOption {
        type = l.types.listOf l.types.unspecified;
        internal = true;
        default = [];
      };
    };

  checkAndTransformConfigFor = user: target: out: config: let
    _file = "github:divnix/hive: ./comb/${user}; target: ${target}";
    locatedConfig = {
      imports = [config];
      inherit _file;
    };
    checked = (evalModulesMinimal {modules = [combCheckModule beeOptions locatedConfig];}).config;
    asserted = let
      failedAsserts = map (x: x.message) (l.filter (x: !x.assertion) checked._hive_erased);
    in
      if failedAsserts != []
      then throw "\nFailed assertions:\n${l.concatStringsSep "\n" (map (x: "- ${x}") failedAsserts)}"
      else checked;
  in
    locatedConfig // (out asserted);

  /*

  We start with:
  ${system}.${user}.${cellBlock}.${machine} = config;

  We want:
  ${user}.${machine} = config; (filtered by system)

  */
  pasteurize = self:
    l.pipe
    (
      l.mapAttrs (system:
        l.mapAttrs (user: blocks: (
          l.pipe blocks [
            (l.attrByPath [cellBlock] {})
            (l.mapAttrs (machine:
              checkAndTransformConfigFor user machine (
                asserted: {
                  environment.etc."nixos/configuration.nix".text = ''
                    throw '''
                      This machine is not managed by nixos-rebuild, but by colmena.
                    '''
                  '';
                  nixpkgs = {
                    inherit (asserted.bee) system pkgs;
                    inherit (asserted.bee.pkgs) config; # nixos modules don't load this
                  };
                }
              )))
            (l.filterAttrs (_: config: config.nixpkgs.system == system))
            (l.mapAttrs (machine: l.nameValuePair "${user}.${machine}"))
          ]
        )))
      (l.intersectAttrs (l.genAttrs l.systems.doubles.all (_: null)) self)
    ) [
      (l.collect (x: x ? name && x ? value))
      l.listToAttrs
    ];

  stir = config: {
    # we consume the already transformed contract here
    evalConfig = import (config.nixpkgs.pkgs.path + "/nixos/lib/eval-config.nix");
    system = config.nixpkgs.system;
  };

  # same as pasteurize, but for home manager configs
  cure = self:
    l.pipe
    (
      l.mapAttrs (system:
        l.mapAttrs (user: blocks: (
          l.pipe blocks [
            (l.attrByPath [cellBlock] {})
            (l.mapAttrs (homecfg:
              checkAndTransformConfigFor user homecfg (
                # We switched off the home-manager nimpkgs module since it
                # does a re-import (and we don't tolerate that interface)
                # so we re-use bee to communicate with the shake function
                # below
                asserted: {bee = {inherit (asserted.bee) system pkgs home;};}
              )))
            (l.filterAttrs (_: config: config.bee.system == system))
            (l.mapAttrs (homecfg: l.nameValuePair "${user}.${homecfg}"))
          ]
        )))
      (l.intersectAttrs (l.genAttrs l.systems.doubles.all (_: null)) self)
    ) [
      (l.collect (x: x ? name && x ? value))
      l.listToAttrs
    ];

  # same as stir, but for home manager configs
  shake = config: extra: let
    # we consume the already transformed contract here
    lib = import (config.bee.home + /modules/lib/stdlib-extended.nix) l;
    hmModules = import (config.bee.home + /modules/modules.nix) {
      inherit (config.bee) pkgs;
      inherit lib;
      check = true;
      # we switch off the nixpkgs module, package instantiation needs
      # to happen on the `std` layer
      useNixpkgsModule = false;
    };
    evaled =
      # need to use the extended lib
      lib.evalModules {
        modules = [config beeOptions extra] ++ hmModules;
        specialArgs = {
          modulesPath = l.toString (config.bee.home + /modules);
        };
      };
  in {
    inherit evaled;
    # system = config.bee.system; # not actually used
  };

  # same as pasteurize, but for disko where the system doesn't matter
  sing = self:
    l.pipe
    (
      l.mapAttrs (system:
        l.mapAttrs (user: blocks: (
          l.pipe blocks [
            (l.attrByPath [cellBlock] {})
            (l.filterAttrs (_: _: "x86_64-linux" == system)) # pick one
            (l.mapAttrs (disko: l.nameValuePair "${user}.${disko}"))
          ]
        )))
      (l.intersectAttrs (l.genAttrs l.systems.doubles.all (_: null)) self)
    ) [
      (l.collect (x: x ? name && x ? value))
      l.listToAttrs
    ];

  # Error reporting
  showAssertions = let
    collectFailed = cfg:
      l.map (x: x.message) (l.filter (x: !x.assertion) cfg.assertions);
    showWarnings = res: let
      f = w: x: l.trace "warning: ${w}" x;
    in
      l.fold f res res.config.warnings;
  in
    evaled:
      showWarnings (
        let
          failed = collectFailed evaled.config;
          failedStr = l.concatStringsSep "\n" (map (x: "- ${x}") failed);
        in
          if failed == []
          then evaled
          else throw "\nFailed assertions:\n${failedStr}"
      );
in {inherit pasteurize stir cure shake sing showAssertions beeOptions;}
