{
  lib,
  rustPlatform,
  kait2en,
}:
# The Rust daemons under `t2-services`: each crate sits in a subdirectory, but
# its path dependencies reach out of it, so the whole tree is unpacked.
lib.extendMkDerivation {
  constructDrv = rustPlatform.buildRustPackage;
  excludeDrvArgNames = [ "component" ];
  extendDrvArgs =
    _finalAttrs:
    {
      component,
      meta ? { },
      postInstall ? "",
      ...
    }:
    {
      pname = "kait2en-${component}";
      inherit (kait2en.modules) version src;

      cargoRoot = "t2-services/t2-${component}";
      buildAndTestSubdir = "t2-services/t2-${component}";

      postInstall = kait2en.installLicenses "kait2en-${component}" + postInstall;

      __structuredAttrs = true;

      meta = {
        homepage = "https://github.com/kaiT2en/KaiT2en-Fedora";
        license = lib.licenses.gpl3Plus;
        maintainers = with lib.maintainers; [ mirkolenz ];
        platforms = [ "x86_64-linux" ];
        # Only used on a T2 Mac, and a bump rebuilds the whole tree.
        hydraPlatforms = [ ];
      }
      // meta;
    };
}
