{
  lib,
  config,
  ...
}:
let
  inherit (lib)
    concatLists
    flip
    mapAttrsToList
    mkDefault
    mkIf
    mkOption
    types
    ;

  cfg = config.users.deterministicIds;
in
{
  options = {
    users.deterministicIds = mkOption {
      default = { };
      description = ''
        Maps a user or group name to its expected uid/gid values. If a user/group is
        used on the system without specifying a uid/gid, this module will assign the
        corresponding ids defined here, or show an error if the definition is missing.
      '';
      type = types.attrsOf (
        types.submodule {
          options = {
            uid = mkOption {
              type = types.nullOr types.int;
              default = null;
              description = "The uid to assign if it is missing in `users.users.<name>`.";
            };
            gid = mkOption {
              type = types.nullOr types.int;
              default = null;
              description = "The gid to assign if it is missing in `users.groups.<name>`.";
            };
          };
        }
      );
    };

    users.users = mkOption {
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            config.uid =
              let
                deterministicUid = cfg.${name}.uid or null;
              in
              mkIf (deterministicUid != null) (mkDefault deterministicUid);
          }
        )
      );
    };

    users.groups = mkOption {
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            config.gid =
              let
                deterministicGid = cfg.${name}.gid or null;
              in
              mkIf (deterministicGid != null) (mkDefault deterministicGid);
          }
        )
      );
    };
  };

  config = {
    assertions =
      concatLists (
        flip mapAttrsToList config.users.users (
          name: user: [
            {
              assertion = user.uid != null;
              message = "non-deterministic uid detected for '${name}', please assign one via `users.deterministicIds`";
            }
            {
              assertion = !user.autoSubUidGidRange;
              message = "non-deterministic subUids/subGids detected for: ${name}";
            }
          ]
        )
      )
      ++ flip mapAttrsToList config.users.groups (
        name: group: {
          assertion = group.gid != null;
          message = "non-deterministic gid detected for '${name}', please assign one via `users.deterministicIds`";
        }
      );
  };
}
