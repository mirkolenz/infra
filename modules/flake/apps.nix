{
  lib,
  self,
  inputs,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    {
      apps = {
        default.program = pkgs.flakectl.withFlags {
          flake = self.outPath;
          cache = "https://mirkolenz.cachix.org";
          build-path = "checks.${system}";
          hash-path = "custom.hashedPackages";
          update-path = "custom.flattenedPackages";
          # Import `./pkgs` from the working tree (not the store-copied
          # `flake.overlays.default`) so package paths like `file = ./release.json`
          # point at the repo and updateScripts can edit them in place. The
          # overlay's nixpkgs matches the one `resolve_nixpkgs` feeds the updater.
          update-overlays = ''
            let
              flake = builtins.getFlake ("git+file://" + toString ./.);
              overlay = import ./pkgs flake.overlayArgs;
            in
            [ overlay ]
          '';
        };
        home-manager.program = pkgs.writeShellScriptBin "home-manager" /* bash */ ''
          exec ${lib.getExe pkgs.home-manager} --flake "${self.outPath}" "$@"
        '';
        t2-updater.program = pkgs.writers.writePython3Bin "t2-updater" {
          libraries = with pkgs.python3Packages; [ requests ];
          doCheck = false;
        } (lib.readFile "${inputs.nixos-hardware}/apple/t2/pkgs/linux-t2/update-patches.py");
      }
      // lib.optionalAttrs pkgs.stdenv.isLinux {
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
