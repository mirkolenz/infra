# Zed tasks, imported by ./default.nix.
# The leading underscore hides this data file from import-tree.
# https://zed.dev/docs/tasks
let
  mkTask =
    attrs:
    {
      hide = "never";
      reveal = "no_focus";
      show_command = false;
      show_summary = false;
      shell.program = "sh";
    }
    // attrs;
in
map mkTask [
  {
    label = "git";
    command = "lazygit";
    hide = "on_success";
    reveal = "always";
    reveal_target = "center";
  }
  {
    label = "todos";
    command = "rg";
    args = [
      "--hyperlink-format=file://{path}:{line}:{column}"
      "--ignore-case"
      "--"
      "todo"
    ];
    reveal = "always";
    reveal_target = "dock";
  }
  {
    label = "latex-compile";
    command = "latexmk";
    args = [
      "-synctex=1"
      "-interaction=nonstopmode"
      "-recorder"
      "-pv"
    ];
    tags = [ "latex-build" ];
  }
  {
    label = "latex-clean";
    command = "latexmk";
    args = [ "-C" ];
    tags = [ "latex-build" ];
  }
  {
    label = "typst-watch";
    command = "typst";
    args = [
      "watch"
      "--root"
      "$ZED_WORKTREE_ROOT"
      "$ZED_FILE"
    ];
  }
  {
    label = "typst-compile";
    command = "typst";
    args = [
      "compile"
      "--root"
      "$ZED_WORKTREE_ROOT"
      "$ZED_FILE"
    ];
  }
]
