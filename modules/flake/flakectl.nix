# The flake-parts module of every flake that flakectl drives, this one included,
# exported as `modules.flake.flakectl`. flakectl runs its tools as `nix run <flake>#<tool>`,
# so the flake exposes the package set of infra, which provides them.
{ self, ... }:
let
  infraPackages = self.legacyPackages;
  module =
    {
      lib,
      config,
      self,
      ...
    }:
    {
      options.flakectl.flags = lib.mkOption {
        type =
          with lib.types;
          attrsOf (oneOf [
            bool
            int
            str
          ]);
        default = { };
        description = "Persistent GNU-style flags of flakectl, the default app, besides `--flake`.";
      };

      config.perSystem =
        { pkgs, system, ... }:
        {
          _module.args.pkgs = lib.mkDefault infraPackages.${system};
          legacyPackages = pkgs;
          apps.default.program = pkgs.flakectl.withFlags ({ flake = self.outPath; } // config.flakectl.flags);
        };
    };
in
{
  imports = [ module ];
  flake.modules.flake.flakectl = module;
}
