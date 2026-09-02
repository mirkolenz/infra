{
  lib,
  buildPythonPackage,
  setuptools,
  darwin,
  pyobjc-core,
  pyobjc-framework-Cocoa,
}:
buildPythonPackage {
  pname = "pyobjc-framework-SystemConfiguration";
  pyproject = true;

  inherit (pyobjc-core) version src;

  sourceRoot = "${pyobjc-core.src.name}/pyobjc-framework-SystemConfiguration";

  # every framework wrapper builds from the same source tree, so the setup patch and the libffi
  # plumbing are shared with the ones nixpkgs packages itself
  inherit (pyobjc-framework-Cocoa) postPatch buildInputs;

  env.NIX_CFLAGS_COMPILE = pyobjc-framework-Cocoa.NIX_CFLAGS_COMPILE;

  build-system = [ setuptools ];

  nativeBuildInputs = [
    darwin.DarwinTools # sw_vers
  ];

  dependencies = [
    pyobjc-core
    pyobjc-framework-Cocoa
  ];

  pythonImportsCheck = [ "SystemConfiguration" ];

  meta = {
    description = "PyObjC wrappers for the SystemConfiguration framework on macOS";
    homepage = "https://github.com/ronaldoussoren/pyobjc";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ mirkolenz ];
    platforms = lib.platforms.darwin;
  };
}
