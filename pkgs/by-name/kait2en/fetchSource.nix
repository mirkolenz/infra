# Sparse checkout of the upstream files one package builds from, plus the
# license notices. An upstream commit touching none of them keeps the hash and
# with it the store path.
{
  lib,
  fetchFromGitHub,
}:
{
  rev,
  hash,
  # The package's own directory, which the builders read as `src.root`.
  root ? null,
  # Further directories with a trailing slash, files without, and exclusions
  # with a leading `!`.
  paths ? [ ],
  # The files of `root` that load the wordmarks the GTK apps show.
  logos ? [ ],
  # The protocol crate of the bridge link daemons.
  bridgexpc ? false,
}:
let
  # Anchored at the repository root, also behind the `!` of an exclusion.
  anchor = path: if lib.hasPrefix "!" path then "!/${lib.removePrefix "!" path}" else "/${path}";
in
fetchFromGitHub {
  owner = "kaiT2en";
  repo = "KaiT2en-Fedora";
  inherit rev hash;
  passthru = { inherit root logos; };
  nonConeMode = true;
  sparseCheckout = map anchor (
    [
      "LICENSE"
      "LICENSING.md"
      "LICENSES/"
    ]
    ++ lib.optional (root != null) "${root}/"
    ++ lib.optionals (logos != [ ]) [
      "assets/kait2en-app-logo.png"
      "assets/kait2en-app-logo-light.png"
    ]
    ++ lib.optional bridgexpc "t2-services/shared/protocols/t2-bridgexpc/"
    ++ paths
  );
}
