{ lib, ... }:
{
  flakectl.flags = {
    build-path = "checks";
    hash-path = "custom.hashedPackages";
    update-path = "custom.flattenedPackages";
  };

  perSystem =
    {
      pkgs,
      config,
      ...
    }:
    {
      apps = {
        neovide.program = pkgs.writeShellScriptBin "neovide" /* bash */ ''
          ${lib.getExe pkgs.neovide} --neovim-bin ${lib.getExe config.packages.nixvim-extras} "$@"
        '';
      };
    };
}
