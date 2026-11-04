{
  lib,
  python3Packages,
  fetchFromGitHub,
  nix-update-script,
}:
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "skills-ref";
  version = "0-unstable-2026-11-04";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "agentskills";
    repo = "agentskills";
    rev = "83021e2be457a9b6679148719c1f6074f0ad975e";
    hash = "sha256-Q2oP3T9rjKIULarCDlsnGl8pow+6aHMB32bJ3gpfodY=";
  };

  sourceRoot = "${finalAttrs.src.name}/skills-ref";

  build-system = [ python3Packages.hatchling ];

  dependencies = with python3Packages; [
    click
    strictyaml
  ];

  nativeCheckInputs = [ python3Packages.pytestCheckHook ];

  pythonImportsCheck = [ "skills_ref" ];

  passthru.updateScript = nix-update-script { extraArgs = [ "--version=branch" ]; };

  __structuredAttrs = true;

  meta = {
    description = "Reference validator for Agent Skills";
    homepage = "https://github.com/agentskills/agentskills/tree/main/skills-ref";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ mirkolenz ];
    mainProgram = "skills-ref";
  };
})
