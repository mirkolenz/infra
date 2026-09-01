{
  lib,
  mkHerdrPlugin,
  fetchFromGitHub,
  nix-update-script,
  bashNonInteractive,
  coreutils,
  gnugrep,
  gnused,
  jq,
}:
mkHerdrPlugin (finalAttrs: {
  pname = "herdr-automatic-rename";
  version = "0.8.0";
  pluginId = "herdr-automatic-rename";

  src = fetchFromGitHub {
    owner = "qu8n";
    repo = "herdr-automatic-rename";
    tag = "v${finalAttrs.version}";
    hash = "sha256-nKi/ePLCNcRF0LkCeyN/A97zo/cppCy7B318FyxxJsw=";
  };

  interpreters = [ bashNonInteractive ];
  pluginFiles = [
    "automatic-rename.sh"
    "config.example.sh"
    "icons.sh"
    "naming.sh"
    "shell"
  ];
  runtimeInputs = [
    coreutils
    gnugrep
    gnused
    jq
  ];

  # the build sandbox has no /usr/bin/env, which the tests use both in their
  # shebangs and to start the engine
  postPatch = ''
    substituteInPlace tests/*.sh tests/mocks/* \
      --replace-quiet "/usr/bin/env bash" "${lib.getExe bashNonInteractive}"
  '';

  nativeCheckInputs = [ jq ];
  doCheck = true;
  checkPhase = ''
    runHook preCheck

    bash tests/run.sh

    runHook postCheck
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Automatic tab naming and navigation labels for herdr";
    homepage = "https://github.com/qu8n/herdr-automatic-rename";
    changelog = "https://github.com/qu8n/herdr-automatic-rename/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
  };
})
