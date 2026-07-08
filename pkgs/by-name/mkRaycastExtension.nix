# Vendored builder for Raycast store extensions (github.com/raycast/extensions):
# builds one extension from its own sparse-checkout `src` with the bundled `ray`
# toolchain. The extension must target a recent @raycast/api (>=1.5x); older ones
# download a `ray` binary at build time, which the sandbox blocks.
#
# Each extension file provides `src`, `version` and `npmDepsHash` like an ordinary
# nixpkgs package. `src` and `version` are left to pass through unchanged
# (extendMkDerivation keeps their source positions), so both `nix-update` (which
# patches the file defining `src`) and `meta.position` (which falls back to
# `version`) resolve to the extension file. The monorepo has no per-extension
# releases, hence `--version=branch` to track the default branch.
{
  lib,
  buildNpmPackage,
}:
lib.extendMkDerivation {
  constructDrv = buildNpmPackage;

  # `name` selects the extension subdirectory; it is not a derivation attribute.
  excludeDrvArgNames = [ "name" ];

  extendDrvArgs =
    _finalAttrs:
    {
      name,
      src,
      passthru ? { },
      meta ? { },
      ...
    }:
    {
      pname = "raycast-extension-${name}";
      sourceRoot = "${src.name}/extensions/${name}";

      # `ray build` emits the extension under $HOME/.config/raycast[-x] (the -x
      # suffix appears only on darwin); collect whichever variant matches.
      installPhase = ''
        runHook preInstall
        mkdir -p "$out"
        cp -r "$HOME"/.config/raycast*/extensions/${name}/. "$out"/
        runHook postInstall
      '';

      passthru = {
        # updateScript = nix-update-script {
        #   extraArgs = [ "--version=branch" ];
        # };
      }
      // passthru;

      meta = {
        homepage = "https://github.com/raycast/extensions/tree/${src.rev}/extensions/${name}";
        platforms = lib.platforms.linux ++ lib.platforms.darwin;
      }
      // meta;
    };
}
