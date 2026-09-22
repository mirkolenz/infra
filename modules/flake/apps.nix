{
  lib,
  self,
  ...
}:
{
  perSystem =
    {
      pkgs,
      system,
      config,
      ...
    }:
    {
      apps = {
        default.program = pkgs.flakectl.withFlags {
          flake = self.outPath;
          build-path = "checks.${system}";
          hash-path = "custom.hashedPackages";
          update-path = "custom.flattenedPackages";
        };
        home-manager.program = pkgs.writeShellScriptBin "home-manager" /* bash */ ''
          exec ${lib.getExe pkgs.home-manager} --flake "${self.outPath}" "$@"
        '';
        neovide.program = pkgs.writeShellScriptBin "neovide" /* bash */ ''
          ${lib.getExe pkgs.neovide} --neovim-bin ${lib.getExe config.packages.nixvim-default} "$@"
        '';
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        disko.program = pkgs.writeShellScriptBin "disko" /* bash */ ''
          name="$1"
          shift
          exec ${lib.getExe pkgs.disko} --flake "${self.outPath}#$name" "$@"
        '';
        disko-install.program = pkgs.writeShellScriptBin "disko-install" /* bash */ ''
          name="$1"
          shift
          exec ${lib.getExe pkgs.disko-install} --flake "${self.outPath}#$name" "$@"
        '';
        nixos-install.program = pkgs.writeShellScriptBin "nixos-install" /* bash */ ''
          name="$1"
          shift
          exec ${lib.getExe pkgs.nixos-install} --flake "${self.outPath}#$name" --no-channel-copy --no-root-password "$@"
        '';
      };
    };
}
