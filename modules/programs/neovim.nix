# Neovim (nixvim) integration into home-manager.
# Every home installs the shared build for its system and its extras and lowMemory flags
# (see modules/flake/nixvim.nix), since nixvim's own home-manager wrapper
# would re-evaluate the module tree once per home.
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
      inherit (config.custom) features;
      package = withSystem pkgs.stdenv.hostPlatform.system (
        perSystem:
        perSystem.config.packages."nixvim-${
          if !features.extras.enable then
            "default"
          else if features.lowMemory.enable then
            "extras-low-memory"
          else
            "extras"
        }"
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
