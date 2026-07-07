# Wires the homeManager buckets with a clear split:
#   base       - user-agnostic foundation (inputs, options, the _module.args
#                bridge, host feature inheritance, home scaffolding). Injected
#                into every home via home-manager.sharedModules, so any future
#                user gets it for free. Home scaffolding lives in home-common.nix.
#   default    - the mlenz home: the cross-platform program set (feature files)
#                and the mlenz identity values.
#   linux      - default + Cosmic (Linux desktop specialisation).
#   darwin     - default + macOS specialisation.
#   standalone - base + own nixpkgs wrapper, combined with a linux/darwin bucket
#                by the home builder; behaviour lives in home-standalone.nix.
# base accesses osConfig via the @-pattern so home-manager does not intercept it
# and force a recursive lookup when it is absent (standalone).
{
  inputs,
  config,
  lib',
  ...
}:
let
  inherit (config.flake) modules nixpkgsConfig overlays;
in
{
  flake.modules.homeManager.base =
    { ... }@args:
    let
      osConfig = args.osConfig or { };
    in
    {
      imports = [
        inputs.nix-index-database.homeModules.nix-index
        inputs.nixvim.homeModules.nixvim
        inputs.opnix.homeManagerModules.default
        (inputs.import-tree ../../options/home-manager)
        (inputs.import-tree ../../options/shared)
      ];
      config = {
        _module.args = {
          inherit inputs lib';
        };
        custom = {
          standalone = !(args ? osConfig);
          features = osConfig.custom.features or { };
        };
      };
    };

  flake.modules.homeManager.linux.imports = [
    modules.homeManager.default
    inputs.cosmic-manager.homeManagerModules.default
    inputs.plasma-manager.homeModules.plasma-manager
  ];

  flake.modules.homeManager.darwin.imports = [
    modules.homeManager.default
  ];

  flake.modules.homeManager.standalone.imports = [
    modules.homeManager.base
    (
      { pkgs, lib, ... }:
      {
        nixpkgs = {
          config = nixpkgsConfig;
          overlays = [ overlays.default ];
        };
        targets.genericLinux.enable = lib.mkDefault pkgs.stdenv.isLinux;
      }
    )
  ];
}
