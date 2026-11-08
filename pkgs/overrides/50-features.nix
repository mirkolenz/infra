final: prev:
# Packages built with features that nixpkgs leaves out of its defaults.
{
  # usql only builds its `most` drivers, which exclude the cgo ODBC driver
  usql = prev.usql.overrideAttrs (prevAttrs: {
    tags = prevAttrs.tags ++ [ "odbc" ];
  });

  # without cachix on its PATH, `--cachix-cache` runs `nix shell nixpkgs#cachix`,
  # which resolves the global registry instead of the locked nixpkgs
  nix-fast-build = prev.nix-fast-build.overrideAttrs (prevAttrs: {
    makeWrapperArgs = prevAttrs.makeWrapperArgs ++ [
      "--prefix"
      "PATH"
      ":"
      (final.lib.makeBinPath [ final.cachix ])
    ];
  });
}
