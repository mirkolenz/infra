# Vendored builder for Raycast store extensions (github.com/raycast/extensions):
# fetches one extension via sparse checkout and builds it with its bundled `ray`
# toolchain. Dependencies use fetchNpmDeps (a build-time fixed-output derivation)
# so evaluation needs no import-from-derivation. The extension must target a
# recent @raycast/api (>=1.5x); older ones download a `ray` binary at build time,
# which the sandbox blocks.
{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  fetchNpmDeps,
  npmHooks,
}:
lib.extendMkDerivation {
  constructDrv = buildNpmPackage;

  # These configure the fetch/build but are not derivation attributes; drop them
  # so `name` does not collide with the `pname`/`version` we set below.
  excludeDrvArgNames = [
    "name"
    "rev"
    "hash"
    "npmDepsHash"
  ];

  extendDrvArgs =
    _finalAttrs:
    {
      name,
      rev,
      hash,
      npmDepsHash,
      version ? "0",
      meta ? { },
      ...
    }:
    let
      src =
        fetchFromGitHub {
          owner = "raycast";
          repo = "extensions";
          inherit rev hash;
          sparseCheckout = [ "/extensions/${name}" ];
        }
        + "/extensions/${name}";
    in
    {
      pname = "raycast-extension-${name}";
      inherit version src;

      npmDeps = fetchNpmDeps {
        inherit src;
        name = "raycast-extension-${name}-npm-deps";
        hash = npmDepsHash;
      };
      npmConfigHook = npmHooks.npmConfigHook;

      # `ray build` emits the extension under $HOME/.config/raycast[-x] (the -x
      # suffix appears only on darwin); collect whichever variant matches.
      installPhase = ''
        runHook preInstall
        mkdir -p "$out"
        cp -r "$HOME"/.config/raycast*/extensions/${name}/. "$out"/
        runHook postInstall
      '';

      meta = {
        description = "Raycast ${name} extension, built for Vicinae";
        homepage = "https://github.com/raycast/extensions/tree/${rev}/extensions/${name}";
        platforms = lib.platforms.linux ++ lib.platforms.darwin;
      }
      // meta;
    };
}
