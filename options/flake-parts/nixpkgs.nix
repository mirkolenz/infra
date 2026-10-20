# One nixpkgs instance per system, shared by every configuration through
# `withSystem`: each `import <nixpkgs>` is a separate evaluation that nix cannot
# deduplicate.
{ inputs, config, ... }:
{
  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config = config.flake.nixpkgsConfig;
        overlays = [ config.flake.overlays.default ];
      };
    };
}
