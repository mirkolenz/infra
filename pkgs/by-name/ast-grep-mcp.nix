{
  lib,
  inputs,
  callPackage,
  runCommand,
  makeBinaryWrapper,
  python3,
  ast-grep,
}:
let
  src = inputs.ast-grep-mcp;
  workspace = inputs.uv2nix.lib.workspace.loadWorkspace { workspaceRoot = src; };
  pythonSet = (callPackage inputs.pyproject-nix.build.packages { python = python3; }).overrideScope (
    lib.composeManyExtensions [
      inputs.pyproject-build-systems.overlays.wheel
      (workspace.mkPyprojectOverlay { sourcePreference = "wheel"; })
    ]
  );
  # The project declares no build system, so uv locks it as virtual
  # and the environment only holds its dependencies.
  venv = pythonSet.mkVirtualEnv "ast-grep-mcp-env" workspace.deps.default;
in
runCommand "ast-grep-mcp"
  {
    nativeBuildInputs = [ makeBinaryWrapper ];
    meta = {
      description = "MCP server for structural code search with ast-grep";
      homepage = "https://github.com/ast-grep/ast-grep-mcp";
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [ mirkolenz ];
      mainProgram = "ast-grep-server";
    };
  }
  ''
    makeWrapper ${lib.getExe' venv "python"} $out/bin/ast-grep-server \
      --add-flags ${src}/main.py \
      --set-default AST_GREP_PATH ${lib.getExe ast-grep}
  ''
