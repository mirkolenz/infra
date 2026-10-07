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
