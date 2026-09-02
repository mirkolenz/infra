{
  lib,
  stdenv,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  dukpy,
  publicsuffixlist,
  pyobjc-framework-SystemConfiguration,
  requests,
  nix-update-script,
}:
buildPythonPackage (finalAttrs: {
  pname = "pypac";
  version = "0.19.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "carsonyl";
    repo = "pypac";
    tag = "v${finalAttrs.version}";
    hash = "sha256-GOqLeZgyvXXXbz9raLhhmgFfmd4zDPvA/R8kG2lBp9Y=";
  };

  build-system = [ setuptools ];

  dependencies = [
    dukpy
    publicsuffixlist
    requests
  ]
  ++ lib.optional stdenv.hostPlatform.isDarwin pyobjc-framework-SystemConfiguration;

  passthru.updateScript = nix-update-script { };

  pythonImportsCheck = [ "pypac" ];

  meta = {
    description = "Proxy auto-config and auto-discovery for Python";
    homepage = "https://github.com/carsonyl/pypac";
    changelog = "https://github.com/carsonyl/pypac/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ mirkolenz ];
  };
})
