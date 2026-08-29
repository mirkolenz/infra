# Builds installer ISO images from the nixos.installer bucket, keyed by system.
{
  inputs,
  lib,
  config,
  ...
}:
let
  inherit (config.flake) modules;
  mkInstaller =
    system: extraModule:
    inputs.nixpkgs-linux-unstable.lib.nixosSystem {
      system = null;
      modules = [
        extraModule
        modules.nixos.installer
        # private instance: `profiles/installation-device.nix`, pulled in by the
        # ISO image, defines `nixpkgs.overlays`.
        config.ownPkgsModuleFor.${system}
      ];
    };

  installers = lib.mapAttrs (system: lib.mapAttrs (_: mkInstaller system)) {
    x86_64-linux = {
      installer-default = { };
      # https://github.com/t2linux/nixos-t2-iso/blob/main/nix/t2-iso-minimal.nix
      installer-apple-t2.imports = [ "${inputs.nixos-hardware}/apple/t2" ];
    };
    aarch64-linux = {
      installer-default = { };
      installer-raspi = {
        imports = [ "${inputs.nixos-hardware}/raspberry-pi/4" ];
        boot.tmp = {
          useTmpfs = true;
          tmpfsSize = "16G";
        };
      };
    };
  };
in
{
  flake.legacyPackages = lib.mapAttrs (
    _: lib.mapAttrs (_: installer: installer.config.system.build.images)
  ) installers;

  # `nix flake check` never forces `legacyPackages`. The image is the target
  # because an installer has no root filesystem or bootloader of its own.
  evalTargets = lib.concatMapAttrs (
    system:
    lib.mapAttrs' (
      name: installer:
      lib.nameValuePair "installer/${name}-${system}" {
        inherit system;
        drvPath = installer.config.system.build.images.iso-installer.drvPath;
      }
    )
  ) installers;
}
