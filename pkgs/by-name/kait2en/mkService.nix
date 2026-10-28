{
  lib,
  rustPlatform,
  kait2en,
}:
# The Rust daemons under `t2-services` and `apps`: each crate sits in a
# subdirectory, but its path dependencies reach out of it, so the whole tree is
# unpacked.
# Callers declare `src` so nix-update writes Cargo hashes to their files.
lib.extendMkDerivation {
  constructDrv = rustPlatform.buildRustPackage;
  excludeDrvArgNames = [
    "component"
    "root"
    "integration"
    "bridge"
  ];
  extendDrvArgs =
    _finalAttrs:
    {
      component,
      # The crate, relative to the repository root.
      root ? "t2-services/t2-${component}",
      # Upstream's units and configuration, from its `install-integration`.
      integration ? false,
      # A daemon on the bridge link, which starts with it instead of waiting for
      # `network-online.target`, see `apple-t2/bridge.nix`.
      bridge ? false,
      meta ? { },
      postInstall ? "",
      ...
    }:
    {
      pname = "kait2en-${component}";
      inherit (kait2en.modules) version;

      cargoRoot = root;
      buildAndTestSubdir = root;

      postInstall =
        kait2en.installLicenses "kait2en-${component}"
        + lib.optionalString integration ''
          make -C $cargoRoot install-integration PREFIX=$out SYSCONFDIR=$out/etc
        ''
        + lib.optionalString bridge ''
          substituteInPlace $out/lib/systemd/system/*.service \
            --replace-fail ' network-online.target' ""
        ''
        + postInstall;

      __structuredAttrs = true;

      meta = kait2en.commonMeta // meta;
    };
}
