{
  lib,
  self,
  ...
}:
{
  perSystem =
    {
      pkgs,
      config,
      ...
    }:
    {
      apps = {
        default.program = pkgs.flakectl.withFlags {
          flake = self.outPath;
          build-path = "checks";
          hash-path = "custom.hashedPackages";
          update-path = "custom.flattenedPackages";
        };
        neovide.program = pkgs.writeShellScriptBin "neovide" /* bash */ ''
          ${lib.getExe pkgs.neovide} --neovim-bin ${lib.getExe config.packages.nixvim-default} "$@"
        '';
      };
    };
}
