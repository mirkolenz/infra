{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  googleapis-common-protos,
  protobuf,
  nix-update-script,
}:
buildPythonPackage (finalAttrs: {
  pname = "protoc-gen-openapiv2";
  version = "0.0.1";
  pyproject = true;

  src = fetchPypi {
    inherit (finalAttrs) pname version;
    hash = "sha256-b3kYjYQsExd8nAVYhFRCw0C0MBG/Z9/vHfw7wGdQZAk=";
  };

  build-system = [ setuptools ];

  dependencies = [
    googleapis-common-protos
    protobuf
  ];

  passthru.updateScript = nix-update-script { };

  pythonImportsCheck = [ "protoc_gen_openapiv2.options" ];

  meta = {
    description = "Python protobuf bindings for the grpc-gateway OpenAPI v2 options";
    homepage = "https://github.com/unionai-oss/protoc-gen-openapiv2";
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ mirkolenz ];
  };
})
