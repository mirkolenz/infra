{
  lib,
  python3Packages,
  fetchFromGitHub,
  nix-update-script,
}:
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "skills-ref";
  version = "0-unstable-2026-08-09";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "agentskills";
    repo = "agentskills";
    rev = "69ef37e9424c0a7ea9dd2293b559e43ec8176379";
    hash = "sha256-9coLvkonrdbkIAf6DVvCH6rfjPuyaCA/eb1RsFBMiSg=";
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
