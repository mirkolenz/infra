# Wires the nixos/darwin buckets: the `_module.args` bridge (inputs + lib'
# sourced from the flake-parts closure), shared home-manager settings, upstream
# input modules, option declarations, and the composite default/children/installer
# variants on top of the bases.
# The package set comes from the configuration builders (see
# options/flake-parts/nixpkgs.nix), so no bucket may set `nixpkgs.config`
# or `nixpkgs.overlays`.
{
  inputs,
  config,
  lib',
  ...
}:
let
  inherit (config.flake) modules;
  systemShared = {
    _module.args = {
      inherit inputs lib';
    };
    home-manager = {
      backupFileExtension = "backup";
      sharedModules = [ config.flake.modules.homeManager.base ];
      useGlobalPkgs = true;
      useUserPackages = true;
    };
  };
in
{
  flake.modules.nixos.base.imports = [
    systemShared
    inputs.home-manager.nixosModules.default
    inputs.quadlet-nix.nixosModules.default
    inputs.determinate.nixosModules.default
    inputs.disko.nixosModules.default
    inputs.opnix.nixosModules.default
    inputs.vicinae.nixosModules.default
    (inputs.import-tree ../../options/shared)
    (inputs.import-tree ../../options/nixos)
  ];

  flake.modules.darwin.base.imports = [
    systemShared
    inputs.home-manager.darwinModules.default
    inputs.determinate.darwinModules.default
    inputs.opnix.darwinModules.default
    (inputs.import-tree ../../options/shared)
    (inputs.import-tree ../../options/nix-darwin)
  ];

  flake.modules.nixos.default =
    { config, ... }:
    {
      imports = [ modules.nixos.base ];
      home-manager.users.${config.custom.user.login} = modules.homeManager.linux;
    };

  flake.modules.nixos.children.imports = [ modules.nixos.base ];

  flake.modules.nixos.installer.imports = [
    {
      _module.args = {
        inherit inputs lib';
      };
    }
    inputs.determinate.nixosModules.default
    (inputs.import-tree ../../options/shared)
  ];

  flake.modules.darwin.default =
    { config, ... }:
    {
      imports = [ modules.darwin.base ];
      home-manager.users.${config.custom.user.login} = modules.homeManager.darwin;
    };
}
