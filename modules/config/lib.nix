{
  inputs,
  lib,
  ...
}: let
  inherit
    (lib)
    all
    any
    assertMsg
    attrNames
    attrValues
    concatLists
    concatMap
    concatMapStrings
    concatStringsSep
    elem
    escapeShellArg
    filter
    flatten
    flip
    foldAttrs
    foldl'
    genAttrs
    genList
    hasInfix
    head
    isAttrs
    mapAttrs'
    mergeAttrs
    min
    mkMerge
    mkOptionType
    nameValuePair
    optionalAttrs
    partition
    range
    recursiveUpdate
    removeSuffix
    reverseList
    showOption
    splitString
    stringToCharacters
    substring
    types
    unique
    warnIf
    ;
in {
  # IP address math library
  # https://gist.github.com/duairc/5c9bb3c922e5d501a1edb9e7b3b845ba
  # Plus some extensions by us
  lib = let
    libWithNet = (import "${inputs.lib-net}/net.nix" {inherit lib;}).lib;
  in
    recursiveUpdate libWithNet {
      types = rec {
        # Checks whether the value is a lazy value without causing
        # it's value to be evaluated
        isLazyValue = x: isAttrs x && x ? _lazyValue;
        # Constructs a lazy value holding the given value.
        lazyValue = value: {_lazyValue = value;};

        # Represents a lazy value of the given type, which
        # holds the actual value as an attrset like { _lazyValue = <actual value>; }.
        # This allows the option to be defined and filtered from a defintion
        # list without evaluating the value.
        lazyValueOf = type:
          mkOptionType rec {
            name = "lazyValueOf ${type.name}";
            inherit (type) description descriptionClass emptyValue getSubOptions getSubModules;
            check = isLazyValue;
            merge = loc: defs:
              assert assertMsg
              (all (x: type.check x._lazyValue) defs)
              "The option `${showOption loc}` is defined with a lazy value holding an invalid type";
                types.mergeOneOption loc defs;
            substSubModules = m: types.uniq (type.substSubModules m);
            functor = (types.defaultFunctor name) // {wrapped = type;};
            nestedTypes.elemType = type;
          };

        # Represents a value or lazy value of the given type that will
        # automatically be coerced to the given type when merged.
        lazyOf = type: types.coercedTo (lazyValueOf type) (x: x._lazyValue) type;
      };
      misc = rec {
        # Counts how often each element occurrs in xs
        countOccurrences = let
          addOrUpdate = acc: x:
            acc // {${x} = (acc.${x} or 0) + 1;};
        in
          foldl' addOrUpdate {};

        # Returns all elements in xs that occur at least twice
        duplicates = xs: let
          occurrences = countOccurrences xs;
        in
          unique (filter (x: occurrences.${x} > 1) xs);

        # Concatenates all given attrsets as if calling a // b in order.
        concatAttrs = foldl' mergeAttrs {};

        # True if the path or string starts with /
        isAbsolutePath = x: substring 0 1 x == "/";

        # Merges all given attributes from the given attrsets using mkMerge.
        # Useful to merge several top-level configs in a module.
        mergeToplevelConfigs = keys: attrs:
          genAttrs keys (attr: mkMerge (map (x: x.${attr} or {}) attrs));

        # Calculates base^exp, but careful, this overflows for results > 2^62
        pow = base: exp: foldl' (a: x: x * a) 1 (genList (_: base) exp);

        # Converts the given hex string to an integer. Only reliable for inputs in [0, 2^63),
        # after that the sign bit will overflow.
        hexToDec = v: let
          literalValues = {
            "0" = 0;
            "1" = 1;
            "2" = 2;
            "3" = 3;
            "4" = 4;
            "5" = 5;
            "6" = 6;
            "7" = 7;
            "8" = 8;
            "9" = 9;
            "a" = 10;
            "b" = 11;
            "c" = 12;
            "d" = 13;
            "e" = 14;
            "f" = 15;
            "A" = 10;
            "B" = 11;
            "C" = 12;
            "D" = 13;
            "E" = 14;
            "F" = 15;
          };
        in
          foldl' (acc: x: acc * 16 + literalValues.${x}) 0 (stringToCharacters v);
      };
      disko = {
        gpt = {
          partGrub = name: start: end: {
            inherit name start end;
            part-type = "primary";
            flags = ["bios_grub"];
          };
          partEfi = name: start: end: {
            inherit name start end;
            fs-type = "fat32";
            bootable = true;
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          partSwap = name: start: end: {
            inherit name start end;
            fs-type = "linux-swap";
            content = {
              type = "swap";
              randomEncryption = true;
            };
          };
          partLuksZfs = name: start: end: {
            inherit start end;
            name = "enc-${name}";
            content = {
              type = "luks";
              name = "enc-${name}";
              extraOpenArgs = ["--allow-discards"];
              content = {
                type = "zfs";
                pool = name;
              };
            };
          };
        };
        zfs = rec {
          defaultZpoolOptions = {
            type = "zpool";
            mountRoot = "/mnt";
            rootFsOptions = {
              compression = "zstd";
              acltype = "posix";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              mountpoint = "none";
              canmount = "off";
              devices = "off";
            };
            options.ashift = "12";
          };

          defaultZfsDatasets = {
            "local" = unmountable;
            "local/root" =
              filesystem "/"
              // {
                postCreateHook = "zfs snapshot rpool/local/root@blank";
              };
            "local/nix" = filesystem "/nix";
            "local/state" = filesystem "/state";
            "safe" = unmountable;
            "safe/persist" = filesystem "/persist";
          };

          unmountable = {type = "zfs_fs";};
          filesystem = mountpoint: {
            type = "zfs_fs";
            options = {
              canmount = "noauto";
              inherit mountpoint;
            };
            # Required to add dependencies for initrd
            inherit mountpoint;
          };
        };
      };
      secrets = let
        rageMasterIdentityArgs = concatMapStrings (x: "-i ${escapeShellArg x} ") inputs.self.secretsConfig.masterIdentities;
        rageExtraEncryptionPubkeys =
          concatMapStrings (
            x:
              if misc.isAbsolutePath x
              then "-R ${escapeShellArg x} "
              else "-r ${escapeShellArg x} "
          )
          inputs.self.secretsConfig.extraEncryptionPubkeys;
      in {
        # TODO replace these by lib.agenix-rekey
        # The arguments required to de-/encrypt a secret in this repository
        rageDecryptArgs = "${rageMasterIdentityArgs}";
        rageEncryptArgs = "${rageMasterIdentityArgs} ${rageExtraEncryptionPubkeys}";
      };
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
            assert assertMsg (i >= (-cap) && i < cap) "The host ${toString i} lies outside of ${n}";
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
          ip = x: head (splitString "/" x);
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
          # mergev4 :: [cidrv4 | ipv4] -> (cidrv4 | null)
          #
          # Returns the smallest cidr network that includes all given networks.
          # If no cidr mask is given, /32 is assumed.
          #
          # Examples:
          #
          # > net.cidr.mergev4 ["192.168.1.1/24" "192.168.6.1/32"]
          # "192.168.0.0/21"
          mergev4 = addrs_: let
            # Append /32 if necessary
            addrs = map (x:
              if hasInfix "/" x
              then x
              else "${x}/32")
            addrs_;
            # The smallest occurring length is the first we need to start checking, since
            # any greater cidr length represents a smaller address range which
            # wouldn't contain all of the original addresses.
            startLength = foldl' min 32 (map libWithNet.net.cidr.length addrs);
            possibleLengths = reverseList (range 0 startLength);
            # The first ip address will be "expanded" in cidr length until it covers all other
            # used addresses.
            firstIp = ip (head addrs);
            # Return the first (i.e. greatest length -> smallest prefix) cidr length
            # in the list that covers all used addresses
            bestLength = head (filter
              # All given addresses must be contained by the generated address.
              (len:
                all (x:
                  libWithNet.net.cidr.contains
                  (ip x)
                  (libWithNet.net.cidr.make len firstIp))
                addrs)
              possibleLengths);
          in
            assert assertMsg (!any (hasInfix ":") addrs) "mergev4 cannot operate on ipv6 addresses";
              if addrs == []
              then null
              else libWithNet.net.cidr.make bestLength firstIp;
          # mergev6 :: [cidrv6 | ipv6] -> (cidrv6 | null)
          #
          # Returns the smallest cidr network that includes all given networks.
          # If no cidr mask is given, /128 is assumed.
          #
          # Examples:
          #
          # > net.cidr.mergev6 ["fd00:dead:cafe::/64" "fd00:fd12:3456:7890::/56"]
          # "fd00:c000::/18"
          mergev6 = addrs_: let
            # Append /128 if necessary
            addrs = map (x:
              if hasInfix "/" x
              then x
              else "${x}/128")
            addrs_;
            # The smallest occurring length is the first we need to start checking, since
            # any greater cidr length represents a smaller address range which
            # wouldn't contain all of the original addresses.
            startLength = foldl' min 128 (map libWithNet.net.cidr.length addrs);
            possibleLengths = reverseList (range 0 startLength);
            # The first ip address will be "expanded" in cidr length until it covers all other
            # used addresses.
            firstIp = ip (head addrs);
            # Return the first (i.e. greatest length -> smallest prefix) cidr length
            # in the list that covers all used addresses
            bestLength = head (filter
              # All given addresses must be contained by the generated address.
              (len:
                all (x:
                  libWithNet.net.cidr.contains
                  (ip x)
                  (libWithNet.net.cidr.make len firstIp))
                addrs)
              possibleLengths);
          in
            assert assertMsg (all (hasInfix ":") addrs) "mergev6 cannot operate on ipv4 addresses";
              if addrs == []
              then null
              else libWithNet.net.cidr.make bestLength firstIp;
          # merge :: [cidr] -> { cidrv4 = (cidrv4 | null); cidrv6 = (cidrv4 | null); }
          #
          # Returns the smallest cidr network that includes all given networks,
          # but yields two separate result for all given ipv4 and ipv6 addresses.
          # Equivalent to calling mergev4 and mergev6 on a partition individually.
          merge = addrs: let
            v4_and_v6 = partition (hasInfix ":") addrs;
          in {
            cidrv4 = mergev4 v4_and_v6.wrong;
            cidrv6 = mergev6 v4_and_v6.right;
          };
          # assignIps :: cidr -> [int | ip] -> [string] -> [ip]
          #
          # Assigns a semi-stable ip address from the given cidr network to each hostname.
          # The algorithm is based on hashing (abusing sha256) with linear probing.
          # The order of hosts doesn't matter. No ip (or offset) from the reserved list
          # will be assigned. The network address and broadcast address will always be reserved
          # automatically.
          #
          # Examples:
          #
          # > net.cidr.assignIps "192.168.100.1/24" [] ["a" "b" "c"]
          # { a = "192.168.100.202"; b = "192.168.100.74"; c = "192.168.100.226"; }
          #
          # > net.cidr.assignIps "192.168.100.1/24" [] ["a" "b" "c" "a-new-elem"]
          # { a = "192.168.100.202"; a-new-elem = "192.168.100.88"; b = "192.168.100.74"; c = "192.168.100.226"; }
          #
          # > net.cidr.assignIps "192.168.100.1/24" [202 "192.168.100.74"] ["a" "b" "c"]
          # { a = "192.168.100.203"; b = "192.168.100.75"; c = "192.168.100.226"; }
          assignIps = net: reserved: hosts: let
            cidrSize = libWithNet.net.cidr.size net;
            capacity = libWithNet.net.cidr.capacity net;
            # The base address of the network. Used to convert ip-based reservations to offsets
            baseAddr = host 0 net;
            # Reserve some values for the network, host and broadcast address.
            # The network and broadcast address should never be used, and we
            # want to reserve the host address for the host. We also convert
            # any ips to offsets here.
            init = unique (
              [0 (capacity - 1)]
              ++ flip map reserved (x:
                if builtins.typeOf x == "int"
                then x
                else -(libWithNet.net.ip.diff baseAddr x))
            );
            nHosts = builtins.length hosts;
            nInit = builtins.length init;
            # Pre-sort all hosts, to ensure ordering invariance
            sortedHosts =
              warnIf
              ((nInit + nHosts) > 0.3 * capacity)
              "assignIps: hash stability may be degraded since utilization is >30%"
              (builtins.sort builtins.lessThan hosts);
            # Generates a hash (i.e. offset value) for a given hostname
            hashElem = x:
              builtins.bitAnd (capacity - 1)
              (misc.hexToDec (builtins.substring 0 16 (builtins.hashString "sha256" x)));
            # Do linear probing. Returns the first unused value at or after the given value.
            probe = avoid: value:
              if elem value avoid
              # TODO lib.mod
              # Poor man's modulo, because nix has no modulo. Luckily we operate on a residue
              # class of x modulo 2^n, so we can use bitAnd instead.
              then probe avoid (builtins.bitAnd (capacity - 1) (value + 1))
              else value;
            # Hash a new element and avoid assigning any existing values.
            assignOne = {
              assigned,
              used,
            }: x: let
              value = probe used (hashElem x);
            in {
              assigned =
                assigned
                // {
                  ${x} = host value net;
                };
              used = [value] ++ used;
            };
          in
            assert assertMsg (cidrSize >= 2 && cidrSize <= 62)
            "assignIps: cidrSize=${toString cidrSize} is not in [2, 62].";
            assert assertMsg (nHosts <= capacity - nInit)
            "assignIps: number of hosts (${toString nHosts}) must be <= capacity (${toString capacity}) - reserved (${toString nInit})";
            # Assign an ip in the subnet to each element, in order
              (foldl' assignOne {
                  assigned = {};
                  used = init;
                }
                sortedHosts)
              .assigned;
        };
        ip = rec {
          # Checks whether the given address (with or without cidr notation) is an ipv4 address.
          isv4 = x: !isv6 x;
          # Checks whether the given address (with or without cidr notation) is an ipv6 address.
          isv6 = hasInfix ":";
        };
        mac = {
          # Adds offset to the given base address and ensures the result is in
          # a locally administered range by replacing the second nibble with a 2.
          addPrivate = base: offset: let
            added = libWithNet.net.mac.add base offset;
            pre = substring 0 1 added;
            suf = substring 2 (-1) added;
          in "${pre}2${suf}";
          # assignMacs :: mac (base) -> int (size) -> [int | mac] (reserved) -> [string] (hosts) -> [mac]
          #
          # Assigns a semi-stable MAC address starting in [base, base + 2^size) to each hostname.
          # The algorithm is based on hashing (abusing sha256) with linear probing.
          # The order of hosts doesn't matter. No mac (or offset) from the reserved list
          # will be assigned.
          #
          # Examples:
          #
          # > net.mac.assignMacs "11:22:33:00:00:00" 24 [] ["a" "b" "c"]
          # { a = "11:22:33:1b:bd:ca"; b = "11:22:33:39:59:4a"; c = "11:22:33:50:7a:e2"; }
          #
          # > net.mac.assignMacs "11:22:33:00:00:00" 24 [] ["a" "b" "c" "a-new-elem"]
          # { a = "11:22:33:1b:bd:ca"; a-new-elem = "11:22:33:d6:5d:58"; b = "11:22:33:39:59:4a"; c = "11:22:33:50:7a:e2"; }
          #
          # > net.mac.assignMacs "11:22:33:00:00:00" 24 ["11:22:33:1b:bd:ca"] ["a" "b" "c"]
          # { a = "11:22:33:1b:bd:cb"; b = "11:22:33:39:59:4a"; c = "11:22:33:50:7a:e2"; }
          assignMacs = base: size: reserved: hosts: let
            capacity = misc.pow 2 size;
            baseAsInt = libWithNet.net.mac.diff base "00:00:00:00:00:00";
            init = unique (
              flip map reserved (x:
                if builtins.typeOf x == "int"
                then x
                else libWithNet.net.mac.diff x base)
            );
            nHosts = builtins.length hosts;
            nInit = builtins.length init;
            # Pre-sort all hosts, to ensure ordering invariance
            sortedHosts =
              warnIf
              ((nInit + nHosts) > 0.3 * capacity)
              "assignMacs: hash stability may be degraded since utilization is >30%"
              (builtins.sort builtins.lessThan hosts);
            # Generates a hash (i.e. offset value) for a given hostname
            hashElem = x:
              builtins.bitAnd (capacity - 1)
              (misc.hexToDec (builtins.substring 0 16 (builtins.hashString "sha256" x)));
            # Do linear probing. Returns the first unused value at or after the given value.
            probe = avoid: value:
              if elem value avoid
              # TODO lib.mod
              # Poor man's modulo, because nix has no modulo. Luckily we operate on a residue
              # class of x modulo 2^n, so we can use bitAnd instead.
              then probe avoid (builtins.bitAnd (capacity - 1) (value + 1))
              else value;
            # Hash a new element and avoid assigning any existing values.
            assignOne = {
              assigned,
              used,
            }: x: let
              value = probe used (hashElem x);
            in {
              assigned =
                assigned
                // {
                  ${x} = libWithNet.net.mac.add value base;
                };
              used = [value] ++ used;
            };
          in
            assert assertMsg (size >= 2 && size <= 62)
            "assignMacs: size=${toString size} is not in [2, 62].";
            assert assertMsg (builtins.bitAnd (capacity - 1) baseAsInt == 0)
            "assignMacs: the size=${toString size} least significant bits of the base mac address must be 0.";
            assert assertMsg (nHosts <= capacity - nInit)
            "assignMacs: number of hosts (${toString nHosts}) must be <= capacity (${toString capacity}) - reserved (${toString nInit})";
            # Assign an ip in the subnet to each element, in order
              (foldl' assignOne {
                  assigned = {};
                  used = init;
                }
                sortedHosts)
              .assigned;
        };
      };
    };
}
