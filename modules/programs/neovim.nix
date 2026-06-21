# Neovim (nixvim) integration into home-manager. The nixvim modules receive
# inputs/lib' through the bridge baked into flake.modules.nixvim.default, so the
# former submoduleWith/specialArgs workaround is no longer needed.
{ config, ... }:
let
  nixvimDefault = config.flake.modules.nixvim.default;
in
{
  flake.modules.homeManager.default =
    { config, lib, ... }:
    {
      programs.nixvim = {
        enable = true;
        nixpkgs.useGlobalPackages = true;
        imports = [ nixvimDefault ];
        custom.features = {
          inherit (config.custom.features) withOptionals;
        };
      };
      programs.neovide = lib.mkIf config.custom.features.withDisplay {
        enable = true;
        settings = {
          fork = true;
          neovim-bin = lib.getExe config.programs.nixvim.build.package;
          no-multigrid = true;
        };
      };
    };
}
