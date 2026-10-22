{
  lib,
  python3Packages,
}:
# The apps of this flake as one Python project, with the libraries of each app as an extra
# named after its script, which `mkPythonApp` packages as an app of its own.
let
  pyproject = lib.importTOML ./pyproject.toml;
  # the nixpkgs packages of PEP 508 requirements, by their names
  packages = map (
    spec: python3Packages.${lib.toLower (lib.head (builtins.match "([A-Za-z0-9_.-]+).*" spec))}
  );
  optional-dependencies = lib.mapAttrs (_: packages) pyproject.project.optional-dependencies;
in
python3Packages.buildPythonPackage {
  pname = pyproject.project.name;
  inherit (pyproject.project) version;
  pyproject = true;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./pyproject.toml
      ./src
    ];
  };

  build-system = [ python3Packages.uv-build ];
  dependencies = packages pyproject.project.dependencies;
  inherit optional-dependencies;

  nativeCheckInputs = [
    python3Packages.pytestCheckHook
  ]
  ++ lib.concatLists (lib.attrValues optional-dependencies);
  pythonImportsCheck = [ "infra_apps" ];

  passthru = {
    inherit (pyproject.project) scripts;
    # the source lives in this repo, so drop the `nix-update` default of `buildPythonPackage`
    updateScript = null;
  };

  meta = {
    inherit (pyproject.project) description;
    homepage = "https://github.com/mirkolenz/infra";
    maintainers = with lib.maintainers; [ mirkolenz ];
  };
}
