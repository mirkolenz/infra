# Neovim (nixvim) integration into home-manager. Every home installs the shared
# build for its system and profile (see modules/flake/nixvim.nix); nixvim's own
# home-manager wrapper would re-evaluate the module tree once per home.
# That build is self-contained (`wrapRc`), so nothing is written to ~/.config/nvim.
{ config, ... }:
let
  inherit (config) nixvimFor;
in
{
  flake.modules.homeManager.default =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      profile = if config.custom.features.extras.enable then "default" else "minimal";
      package = nixvimFor.${pkgs.stdenv.hostPlatform.system}.${profile}.config.build.package;
    in
    {
      home.packages = [ package ];

      programs.neovide = lib.mkIf config.custom.features.graphical.enable {
        enable = true;
        settings = {
          fork = true;
          neovim-bin = lib.getExe package;
          no-multigrid = true;
        };
      };
    };
}
