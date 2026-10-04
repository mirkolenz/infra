{
  lib,
  rustPlatform,
  kait2en,
}:
# The Rust daemons under `t2-services` and `apps`: each crate sits in a
# subdirectory, but its path dependencies reach out of it, so the whole tree is
# unpacked.
lib.extendMkDerivation {
  constructDrv = rustPlatform.buildRustPackage;
  excludeDrvArgNames = [
    "component"
    "root"
    "integration"
  ];
  extendDrvArgs =
    _finalAttrs:
    {
      component,
      # The crate, relative to the repository root.
      root ? "t2-services/t2-${component}",
      # Upstream's units and configuration, from its `install-integration`.
      integration ? false,
      meta ? { },
      postInstall ? "",
      ...
    }:
    {
      pname = "kait2en-${component}";
      inherit (kait2en.modules) version src;

      cargoRoot = root;
      buildAndTestSubdir = root;

      # The daemons on the bridge link start with it instead of waiting for
      # `network-online.target`, see `apple-t2/bridge.nix`.
      postInstall =
        kait2en.installLicenses "kait2en-${component}"
        + lib.optionalString integration ''
          make -C $cargoRoot install-integration PREFIX=$out SYSCONFDIR=$out/etc
          substituteInPlace $out/lib/systemd/system/*.service \
            --replace-fail ' network-online.target' ""
        ''
        + postInstall;

      __structuredAttrs = true;

      meta = kait2en.commonMeta // meta;
    };
}
