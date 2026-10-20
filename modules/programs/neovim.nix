# Neovim (nixvim) integration into home-manager. Every home installs the shared
# build for its system and extras flag (see modules/flake/nixvim.nix); nixvim's own
# home-manager wrapper would re-evaluate the module tree once per home.
# That build is self-contained (`wrapRc`), so nothing is written to ~/.config/nvim.
{ withSystem, ... }:
{
  flake.modules.homeManager.default =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      package = withSystem pkgs.stdenv.hostPlatform.system (
        perSystem:
        perSystem.config.packages."nixvim-${if config.custom.features.extras.enable then "extras" else "default"}"
      );
    in
    {
      home.packages = [ package ];

      programs.neovide = {
        enable = false;
        settings = {
          fork = true;
          neovim-bin = lib.getExe package;
          no-multigrid = true;
        };
      };
    };
}
