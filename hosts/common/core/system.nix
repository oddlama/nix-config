{
  inputs,
  lib,
  nodeName,
  nodePath,
  ...
}: {
  # IP address math library
  # https://gist.github.com/duairc/5c9bb3c922e5d501a1edb9e7b3b845ba
  # Plus some extensions by us
  lib = let
    libWithNet = (import "${inputs.lib-net}/net.nix" {inherit lib;}).lib;
  in
    lib.recursiveUpdate libWithNet {
      net = {
        cidr = rec {
          host = i: n: let
            cap = libWithNet.net.cidr.capacity n;
          in
            assert lib.assertMsg (i >= (-cap) && i < cap) "The host ${toString i} lies outside of ${n}";
              libWithNet.net.cidr.host i n;
          hostCidr = n: x: "${libWithNet.net.cidr.host n x}/${toString (libWithNet.net.cidr.length x)}";
          ip = x: lib.head (lib.splitString "/" x);
          canonicalize = x: libWithNet.net.cidr.make (libWithNet.net.cidr.length x) (ip x);
        };
        mac = {
          # Adds offset to the given base address and ensures the result is in
          # a locally administered range by replacing the second nibble with a 2.
          addPrivate = base: offset: let
            added = libWithNet.net.mac.add base offset;
            pre = lib.substring 0 1 added;
            suf = lib.substring 2 (-1) added;
          in "${pre}2${suf}";
        };
      };
    };

  # Setup secret rekeying parameters
  rekey = {
    inherit
      (inputs.self.secrets)
      masterIdentities
      extraEncryptionPubkeys
      ;

    # This is technically impure, but intended. We need to rekey on the
    # current system due to yubikey availability.
    forceRekeyOnSystem = builtins.extraBuiltins.unsafeCurrentSystem;
    hostPubkey = let
      pubkeyPath = nodePath + "/secrets/host.pub";
    in
      lib.mkIf (lib.pathExists pubkeyPath || lib.trace "Missing pubkey for ${nodeName}: ${toString pubkeyPath} not found, using dummy replacement key for now." false)
      pubkeyPath;
  };

  boot = {
    initrd.systemd.enable = true;
    # Add "rd.systemd.unit=rescue.target" to debug initrd
    kernelParams = ["log_buf_len=10M"];
    tmp.useTmpfs = true;
  };

  # Disable sudo which is entierly unnecessary.
  security.sudo.enable = false;

  time.timeZone = lib.mkDefault "Europe/Berlin";
  i18n.defaultLocale = "C.UTF-8";
  console.keyMap = "de-latin1-nodeadkeys";

  systemd.enableUnifiedCgroupHierarchy = true;
  users.mutableUsers = false;
}
