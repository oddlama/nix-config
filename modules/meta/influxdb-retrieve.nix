{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    mkOption
    types
    ;

  cfg = config.services.influxdb2;
in {
  options.services.influxdb2.provision.retrieveToken = mkOption {
    type = types.functionTo (types.functionTo types.str);
    readOnly = true;
    description = "Script that returns a agenix-rekey generator to retrieve the given token";
    default = def: let
      id = builtins.substring 0 32 (builtins.hashString "sha256" "${def.user}:${def.org}:${def.name}");
    in
      {
        pkgs,
        lib,
        ...
      }: ''
        echo " -> Retrieving influxdb token [34m${def.name}[m for org [32m${def.org}[m on [33m${config.node.name}[m" >&2
        ssh ${config.node.name} -- \
          'bash -c '"'"'influx auth list --json --token "$(< ${cfg.provision.initialSetup.tokenFile})"'"'" \
          | ${lib.getExe pkgs.jq} -r '.[] | select(.description | contains("${id}")) | .token' \
          || die "Could not list/find influxdb api token '${def.name}' (${id})"
      '';
  };
}
