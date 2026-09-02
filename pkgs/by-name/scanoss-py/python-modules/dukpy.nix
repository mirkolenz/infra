{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  nix-update-script,
}:
buildPythonPackage (finalAttrs: {
  pname = "dukpy";
  version = "0.6.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "amol-";
    repo = "dukpy";
    tag = finalAttrs.version;
    hash = "sha256-BSgKu5sjWMGJt2zH2vHnWXGTRLxlX/+Dz2/lBTDJuWM=";
  };

  build-system = [ setuptools ];

  passthru.updateScript = nix-update-script { };

  pythonImportsCheck = [ "dukpy" ];

  meta = {
    description = "Simple JavaScript interpreter for Python";
    homepage = "https://github.com/amol-/dukpy";
    changelog = "https://github.com/amol-/dukpy/releases/tag/${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ mirkolenz ];
    mainProgram = "dukpy";
  };
})
