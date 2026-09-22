# Option + builder for installer images. Installers register
# `configurations.installer.<system>.<name>` (see modules/flake/installers.nix)
# and are exposed as `legacyPackages.<system>.installer-<name>`, holding every
# image variant of `system.build.images`. They are no deploy target, so they stay
# out of nixosConfigurations.
{
  lib,
  config,
  ...
}:
let
  installers = lib.mapAttrs (
    system: lib.mapAttrs (_: module: config.nixosSystemFor.${system} [ module ])
  ) config.configurations.installer;
in
{
  options.configurations.installer = lib.mkOption {
    type = lib.types.attrsOf (lib.types.lazyAttrsOf lib.types.deferredModule);
    default = { };
  };

  config = {
    flake.legacyPackages = lib.mapAttrs (
      _:
      lib.mapAttrs' (
        name: installer: lib.nameValuePair "installer-${name}" installer.config.system.build.images
      )
    ) installers;

    # The image is the target because an installer has no root filesystem or
    # bootloader of its own.
    evalTargets.installer = lib.concatMapAttrs (
      system:
      lib.mapAttrs' (
        name: installer:
        lib.nameValuePair "${name}-${system}" {
          inherit system;
          package = installer.config.system.build.images.iso-installer;
        }
      )
    ) installers;
  };
}
