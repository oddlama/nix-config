{
  inputs,
  config,
  lib,
  nodeName,
  nodePath,
  microvm,
  pkgs,
  ...
}: let
  inherit
    (lib)
    mapAttrs
    mdDoc
    mkDefault
    mkForce
    mkIf
    mkOption
    types
    ;

  cfg = config.extra.microvms;

  defineMicrovm = vmName: vmCfg: let
    node =
      (import ../nix/generate-node.nix inputs)
      "${nodeName}-microvm-${vmName}" {
        inherit (vmCfg) system;
        config = nodePath + "/microvms/${vmName}";
      };
  in {
    inherit (node) pkgs specialArgs;
    config = {
      imports = [microvm.microvm] ++ node.imports;

      microvm = {
        hypervisor = mkDefault "cloud-hypervisor";

        # Share the nix-store of the host
        shares = [
          {
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
            tag = "ro-store";
            proto = "virtiofs";
          }
        ];
      };

      # TODO change once microvms are compatible with stage-1 systemd
      boot.initrd.systemd.enable = mkForce false;
    };
  };
in {
  imports = [microvm.host];

  options.extra.microvms = mkOption {
    default = {};
    description = "Provides a base configuration for MicroVMs.";
    type = types.attrsOf (types.submodule {
      options = {
        system = mkOption {
          type = types.str;
          description = mdDoc "The system that this microvm should use";
        };
      };
    });
  };

  config = {
    microvm = {
      host.enable = cfg != {};
      declarativeUpdates = true;
      restartIfChanged = true;
      vms = mkIf (cfg != {}) (mapAttrs defineMicrovm cfg);
    };
  };
}
