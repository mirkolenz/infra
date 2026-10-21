# Zed debug scenarios, imported by ./default.nix.
# The leading underscore hides this data file from import-tree.
# https://zed.dev/docs/debugger
[
  {
    label = "Debug active Python file";
    adapter = "Debugpy";
    program = "$ZED_FILE";
    request = "launch";
    cwd = "$ZED_WORKTREE_ROOT";
  }
  {
    label = "Debug active JavaScript file";
    adapter = "JavaScript";
    program = "$ZED_FILE";
    request = "launch";
    cwd = "$ZED_WORKTREE_ROOT";
    type = "pwa-node";
  }
  {
    label = "JavaScript debug terminal";
    adapter = "JavaScript";
    request = "launch";
    cwd = "$ZED_WORKTREE_ROOT";
    console = "integratedTerminal";
    type = "pwa-node";
  }
]
