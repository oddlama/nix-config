{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  users.users.root = {
    hashedPassword = "$6$EBo/CaxB.dQoq2W8$lo2b5vKgJlLPdGGhEqa08q3Irf1Zd1PcFBCwJOrG8lqjwbABkn1DEhrMh1P3ezwnww2HusUBuZGDSMa4nvSQg1";
    openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5Uq+CDy5Pmt3If5M6d8K/Q7HArU6sZ7sgoj3T521Wm"];
    shell = pkgs.fish;
  };

  home-manager.users.root = {
    imports = [
      ../common
    ];

    home.username = config.users.users.root.name;
    home.uid = config.users.users.root.uid;
  };
}
