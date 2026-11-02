{
  lib,
  python3Packages,
  fetchFromGitHub,
  nix-update-script,
}:
# A single stdlib-only script, whose repository is the asd-ste100 skill as well.
python3Packages.buildPythonApplication {
  pname = "ste-lint";
  version = "0-unstable-2026-11-02";
  pyproject = false;

  src = fetchFromGitHub {
    owner = "danyuchn";
    repo = "asd-ste100-skill";
    rev = "833810d3866645f579085aa76803541892bde692";
    hash = "sha256-1NtERrl9nAEwYTZx5EOKWFm2zCi98RPmC2OvwuhnNr0=";
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
