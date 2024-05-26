{
  lib,
  options,
  ...
}: let
  inherit
    (lib)
    mkOption
    types
    ;
in {
  options = {
    globals = mkOption {
      default = {};
      type = types.submodule {
        options = {
          services = mkOption {
            type = types.attrsOf (types.submodule {
              options = {
                domain = mkOption {
                  type = types.str;
                  description = "";
                };
              };
            });

            #telegrafChecks = mkOption {
            #  type = types.attrsOf (types.submodule {
            #    options = {
            #      domain = mkOption {};
            #    };
            #  });
            #};
          };
        };
      };
    };

    _globalsDefs = mkOption {
      type = types.unspecified;
      default = options.globals.definitions;
      readOnly = true;
      internal = true;
    };
  };
}
