{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  binaryornot,
  crc32c,
  nix-update-script,
}:
buildPythonPackage (finalAttrs: {
  pname = "scanoss-winnowing";
  version = "0.8.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "scanoss";
    repo = "scanoss-winnowing.py";
    tag = "v${finalAttrs.version}";
    hash = "sha256-tSLai3U675Nd+SE521Hixr4JJadGdwuHTDKSjX5Evg0=";
  };

  # twine is only used for publishing and Cython is unused, the C sources are hand-written
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail '["setuptools", "wheel", "twine", "Cython"]' '["setuptools", "wheel"]'
  '';

  build-system = [ setuptools ];

  dependencies = [
    binaryornot
    crc32c
  ];

  passthru.updateScript = nix-update-script { };

  pythonImportsCheck = [ "scanoss_winnowing.winnowing" ];

  meta = {
    description = "Python library implementing a C version of the SCANOSS winnowing algorithm";
    homepage = "https://github.com/scanoss/scanoss-winnowing.py";
    changelog = "https://github.com/scanoss/scanoss-winnowing.py/blob/${finalAttrs.src.tag}/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ mirkolenz ];
  };
})
