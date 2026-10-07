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
          # always the linux package set, so that the hashes match the ones of CI
          hash-path = "legacyPackages.${pkgs.stdenv.hostPlatform.parsed.cpu.name}-linux.custom.hashedPackages";
          update-path = "custom.flattenedPackages";
        };
        neovide.program = pkgs.writeShellScriptBin "neovide" /* bash */ ''
          ${lib.getExe pkgs.neovide} --neovim-bin ${lib.getExe config.packages.nixvim-default} "$@"
        '';
      };
    };
}
