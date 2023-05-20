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
          # host :: (ip | mac | integer) -> cidr -> ip
          #
          # Wrapper that extends the original host function to
          # check whether the argument `n` is in-range for the given cidr.
          #
          # Examples:
          #
          # > net.cidr.host 255 "192.168.1.0/24"
          # "192.168.1.255"
          # > net.cidr.host (256) "192.168.1.0/24"
          # <fails with an error message>
          # > net.cidr.host (-1) "192.168.1.0/24"
          # "192.168.1.255"
          # > net.cidr.host (-256) "192.168.1.0/24"
          # "192.168.1.0"
          # > net.cidr.host (-257) "192.168.1.0/24"
          # <fails with an error message>
          host = i: n: let
            cap = libWithNet.net.cidr.capacity n;
          in
            assert lib.assertMsg (i >= (-cap) && i < cap) "The host ${toString i} lies outside of ${n}";
              libWithNet.net.cidr.host i n;
          # hostCidr :: (ip | mac | integer) -> cidr -> cidr
          #
          # Returns the nth host in the given cidr range (like cidr.host)
          # but as a cidr that retains the original prefix length.
          #
          # Examples:
          #
          # > net.cidr.hostCidr 2 "192.168.1.0/24"
          # "192.168.1.2/24"
          hostCidr = n: x: "${libWithNet.net.cidr.host n x}/${toString (libWithNet.net.cidr.length x)}";
          # ip :: (cidr | ip) -> ip
          #
          # Returns just the ip part of the cidr.
          #
          # Examples:
          #
          # > net.cidr.ip "192.168.1.100/24"
          # "192.168.1.100"
          # > net.cidr.ip "192.168.1.100"
          # "192.168.1.100"
          ip = x: lib.head (lib.splitString "/" x);
          # canonicalize :: cidr -> cidr
          #
          # Replaces the ip of the cidr with the canonical network address
          # (first contained address in range)
          #
          # Examples:
          #
          # > net.cidr.canonicalize "192.168.1.100/24"
          # "192.168.1.0/24"
          canonicalize = x: libWithNet.net.cidr.make (libWithNet.net.cidr.length x) (ip x);
          # coercev4 :: [cidr4] -> (cidr4 | null)
          #
          # Returns the smallest cidr network that includes all given addresses
          #
          # Examples:
          #
          # > net.cidr.coercev4 ["192.168.1.1/24" "192.168.6.1/32"]
          # "192.168.0.0/21"
          coercev4 = addrs: let
            # The smallest occurring length is the first we need to start checking, since
            # any greater cidr length represents a smaller address range which
            # wouldn't contain all of the original addresses.
            startLength = lib.foldl' lib.min 32 (map libWithNet.net.cidr.length addrs);
            possibleLengths = lib.reverseList (lib.range 0 startLength);
            # The first ip address will be "expanded" in cidr length until it covers all other
            # used addresses.
            firstIp = ip (lib.head addrs);
            # Return the first (i.e. greatest length -> smallest prefix) cidr length
            # in the list that covers all used addresses
            bestLength = lib.head (lib.filter
              # All given addresses must be contained by the generated address.
              (len:
                lib.all
                (x:
                  libWithNet.net.cidr.contains
                  (ip x)
                  (libWithNet.net.cidr.make len firstIp))
                addrs)
              possibleLengths);
          in
            assert lib.assertMsg (!lib.any (lib.hasInfix ":") addrs) "coercev4 cannot operate on ipv6 addresses";
              if addrs == []
              then null
              else libWithNet.net.cidr.make bestLength firstIp;
          # coercev6 :: [cidr6] -> (cidr6 | null)
          #
          # Returns the smallest cidr network that includes all given addresses
          #
          # Examples:
          #
          # > net.cidr.coercev6 ["fd00:dead:cafe::/64" "fd00:fd12:3456:7890::/56"]
          # "fd00:c000::/18"
          coercev6 = addrs: let
            # The smallest occurring length is the first we need to start checking, since
            # any greater cidr length represents a smaller address range which
            # wouldn't contain all of the original addresses.
            startLength = lib.foldl' lib.min 128 (map libWithNet.net.cidr.length addrs);
            possibleLengths = lib.reverseList (lib.range 0 startLength);
            # The first ip address will be "expanded" in cidr length until it covers all other
            # used addresses.
            firstIp = ip (lib.head addrs);
            # Return the first (i.e. greatest length -> smallest prefix) cidr length
            # in the list that covers all used addresses
            bestLength = lib.head (lib.filter
              # All given addresses must be contained by the generated address.
              (len:
                lib.all
                (x:
                  libWithNet.net.cidr.contains
                  (ip x)
                  (libWithNet.net.cidr.make len firstIp))
                addrs)
              possibleLengths);
          in
            assert lib.assertMsg (lib.all (lib.hasInfix ":") addrs) "coercev6 cannot operate on ipv4 addresses";
              if addrs == []
              then null
              else libWithNet.net.cidr.make bestLength firstIp;
          # coerce :: [cidr] -> { cidrv4 = (cidr4 | null); cidrv6 = (cidr4 | null); }
          #
          # Returns the smallest cidr network that includes all given addresses,
          # but yields two separate result for all given ipv4 and ipv6 addresses.
          # Equivalent to calling coercev4 and coercev6 on a partition individually.
          coerce = addrs: let
            v4_and_v6 = lib.partition (lib.hasInfix ":") addrs;
          in {
            cidrv4 = coercev4 v4_and_v6.wrong;
            cidrv6 = coercev6 v4_and_v6.right;
          };
        };
        ip = {
          # Checks whether the given address (with or without cidr notation) is an ipv6 address.
          isv6 = lib.hasInfix ":";
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

  # Just before switching, remove the agenix directory if it exists.
  # This can happen when a secret is used in the initrd because it will
  # then be copied to the initramfs under the same path. This materializes
  # /run/agenix as a directory which will cause issues when the actual system tries
  # to create a link called /run/agenix. Agenix should probably fail in this case,
  # but doesn't and instead puts the generation link into the existing directory.
  # TODO See https://github.com/ryantm/agenix/pull/187.
  system.activationScripts.removeAgenixLink.text = "[[ -d /run/agenix ]] && rm -rf /run/agenix";
  system.activationScripts.agenixInstall.deps = ["removeAgenixLink"];

  # Disable sudo which is entierly unnecessary.
  security.sudo.enable = false;

  time.timeZone = lib.mkDefault "Europe/Berlin";
  i18n.defaultLocale = "C.UTF-8";
  console.keyMap = "de-latin1-nodeadkeys";

  systemd.enableUnifiedCgroupHierarchy = true;
  users.mutableUsers = false;
}
