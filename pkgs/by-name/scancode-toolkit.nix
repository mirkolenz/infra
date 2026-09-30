{
  lib,
  python3Packages,
}:
# the darwin fixes for scancode's native plugins live in `pkgs/overrides/ports.nix`,
# since `lookup-license` and `sbom-compliance-tool` reach the same plugins independently
(python3Packages.toPythonApplication python3Packages.scancode-toolkit).overrideAttrs (old: {
  meta = old.meta // {
    mainProgram = "scancode";
    # too large for the binary cache
    hydraPlatforms = [ ];
    maintainers = old.meta.maintainers ++ [ lib.maintainers.mirkolenz ];
  };
})
