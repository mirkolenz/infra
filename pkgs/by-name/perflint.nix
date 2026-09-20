{
  lib,
  python3Packages,
  fetchFromGitHub,
  nix-update-script,
}:
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "perflint";
  version = "0.8.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "tonybaloney";
    repo = "perflint";
    tag = finalAttrs.version;
    hash = "sha256-jdfTxqE+9awBDExEq1vtqqW6nlWPPIRjknis8Q2Q9z0=";
  };

  build-system = [ python3Packages.flit-core ];

  dependencies = [ python3Packages.pylint ];

  # upstream caps pylint at <4 while nixpkgs is already on 4.x. The checker api perflint
  # registers against is unchanged, which the install check below proves rather than
  # assumes, so a future pylint bump fails the build instead of silently reporting nothing
  pythonRelaxDeps = [ "pylint" ];

  pythonImportsCheck = [ "perflint" ];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    export HOME=$(mktemp -d)
    cat > loop.py <<'EOF'
    def f(xs):
        for x in xs:
            print(len(xs), x)
    EOF
    # pylint exits with a bitmask whenever it reports anything, which is the point here
    $out/bin/perflint loop.py > report.txt || true
    grep -q W8201 report.txt

    runHook postInstallCheck
  '';

  passthru.updateScript = nix-update-script { };

  __structuredAttrs = true;

  meta = {
    description = "Pylint extension reporting performance anti-patterns such as loop-invariant work and needless copies";
    homepage = "https://github.com/tonybaloney/perflint";
    changelog = "https://github.com/tonybaloney/perflint/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ mirkolenz ];
    mainProgram = "perflint";
  };
})
