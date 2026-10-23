final: prev:
# The darwin sandbox profile lists every input store path, and macOS rejects profiles
# over 64 KiB (roughly 750 paths), so these aggregators of the system and home-manager
# configs only build outside of it, which `sandbox = relaxed` allows via `__noChroot`.
# Matching their names leaves every other derivation and thus the binary caches untouched.
# todo: drop once nix generates profiles that scale, https://github.com/NixOS/nix/issues/16613
let
  inherit (prev) lib;
  pattern = lib.concatStringsSep "|" [
    "activation-.+"
    "darwin-system-.+"
    "etc"
    "hm-putter\\.json"
    "home-manager-(applications|files|fonts|generation|path)"
    "nvim-treesitter-grammars"
    "user-environment"
  ];
in
lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
  # Wrapping the result keeps the attrs untouched, as conditional attrs would recurse through finalAttrs.
  stdenvNoCC = prev.stdenvNoCC // {
    mkDerivation =
      args:
      let
        drv = prev.stdenvNoCC.mkDerivation args;
      in
      if lib.match pattern drv.name != null then drv.overrideAttrs { __noChroot = true; } else drv;
  };
}
