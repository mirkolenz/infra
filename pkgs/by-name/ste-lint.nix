{
  lib,
  python3Packages,
  fetchFromGitHub,
  nix-update-script,
}:
# A single stdlib-only script, whose repository is the asd-ste100 skill as well.
python3Packages.buildPythonApplication {
  pname = "ste-lint";
  version = "0-unstable-2026-11-20";
  pyproject = false;

  src = fetchFromGitHub {
    owner = "danyuchn";
    repo = "asd-ste100-skill";
    rev = "65c8ab6ef5fcb3619c8e6daca43e68627f3d7b4a";
    hash = "sha256-UGqEuVtN+RN5FZMW5J6Vl6D9S3t1PEPogclOwC37lkc=";
  };

  installPhase = ''
    runHook preInstall

    install -Dm755 scripts/ste-lint.py $out/bin/ste-lint

    runHook postInstall
  '';

  # run against the installed script, like every check of the python builders
  checkPhase = ''
    runHook preCheck

    $out/bin/ste-lint --selftest

    runHook postCheck
  '';

  passthru.updateScript = nix-update-script { extraArgs = [ "--version=branch" ]; };

  __structuredAttrs = true;

  meta = {
    description = "Linter for the structural rules of Simplified Technical English (ASD-STE100)";
    homepage = "https://github.com/danyuchn/asd-ste100-skill";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ mirkolenz ];
    mainProgram = "ste-lint";
  };
}
