{
  lib,
  python3Packages,
  fetchFromGitHub,
  versionCheckHook,
  nix-update-script,
}:
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "uv-bump";
  version = "0.6.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "zundertj";
    repo = "uv-bump";
    tag = finalAttrs.version;
    hash = "sha256-JKiEdUhRjiKk1MND/V3RDE22PQ4MohjsoNP7RMxfHHw=";
  };

  # upstream caps uv_build below the version nixpkgs ships, whose build api is unchanged
  postPatch = ''
    sed -i 's/"uv_build[^"]*"/"uv_build"/' pyproject.toml
  '';

  build-system = [ python3Packages.uv-build ];

  nativeCheckInputs = [ python3Packages.pytestCheckHook ];

  nativeInstallCheckInputs = [ versionCheckHook ];

  pythonImportsCheck = [ "uv_bump" ];

  passthru.updateScript = nix-update-script { };

  __structuredAttrs = true;

  meta = {
    description = "Bump the minimum versions in pyproject.toml to those resolved in uv.lock";
    homepage = "https://github.com/zundertj/uv-bump";
    changelog = "https://github.com/zundertj/uv-bump/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ mirkolenz ];
    mainProgram = "uv-bump";
  };
})
