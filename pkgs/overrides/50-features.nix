_final: prev:
# Packages built with features that nixpkgs leaves out of its defaults.
{
  # usql only builds its `most` drivers, which exclude the cgo ODBC driver
  usql = prev.usql.overrideAttrs (prevAttrs: {
    tags = prevAttrs.tags ++ [ "odbc" ];
  });
}
