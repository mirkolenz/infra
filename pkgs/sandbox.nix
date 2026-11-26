_: prev:
# The darwin sandbox profile lists every path in the input closure,
# which costs about 6 ms per path, so 20 s for the 7000 paths of the system.
# These locally built aggregators of the system and home-manager configs thus build outside of it,
# which `sandbox = relaxed` allows via `__noChroot`.
# Matching their names leaves every other derivation and thus the binary caches untouched.
let
  inherit (prev) lib;
  pattern = lib.concatStringsSep "|" [
    "activation-.+"
    "darwin-system-.+"
    "etc"
    "hm-putter\\.json"
    "home-manager-(applications|files|fonts|generation|path)"
    "nixvim"
    "nvim-treesitter-grammars"
    "packdir-start"
    "system-(applications|path)"
    "user-environment"
    "vim-pack-dir"
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
