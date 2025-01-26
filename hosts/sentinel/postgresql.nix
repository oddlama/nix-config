{ pkgs, ... }:
{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16_jit;

    # Doesn't work with plausible, since it wants to connect as the postgres user
    # for some (probably unecessary) reason.
    #
    # authentication = lib.mkForce ''
    #   #type database  DBuser   auth-method optional_ident_map
    #   local sameuser  all      peer        map=superuser_map
    #   local all       postgres peer        map=superuser_map
    # '';
    #
    # identMap = ''
    #   # ArbitraryMapName systemUser DBUser
    #   superuser_map      root      postgres
    #   superuser_map      postgres  postgres
    #   # Let other names login as themselves
    #   superuser_map      /^(.*)$   \1
    # '';
  };
}
