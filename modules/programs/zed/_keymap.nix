# Zed key bindings, imported by ./default.nix.
# The leading underscore hides this data file from import-tree.
# https://zed.dev/docs/key-bindings
let
  spawn = task_name: [
    "task::Spawn"
    { inherit task_name; }
  ];
in
[
  {
    bindings = {
      "cmd-alt-n" = "agent::NewTerminalThread";
      "cmd-r" = "workspace::Reload";
      "cmd-shift-g" = spawn "git";
      "ctrl-/" = "workspace::NewCenterTerminal";
      "ctrl-`" = "terminal_panel::Toggle";
    };
  }
  {
    context = "Editor && extension == tex";
    bindings = {
      "cmd-alt-c" = spawn "latex-compile";
      "cmd-alt-shift-c" = spawn "latex-clean";
    };
  }
  {
    context = "Editor && extension == typ";
    bindings = {
      "cmd-alt-c" = spawn "typst-compile";
      "cmd-alt-w" = spawn "typst-watch";
    };
  }
  {
    context = "Editor";
    bindings = {
      "cmd-shift-a" = "editor::SortLinesCaseInsensitive";
      "alt-shift-a" = spawn "sort";
      "tab" = "editor::Tab";
    };
  }
  {
    context = "Editor && showing_completions";
    bindings."tab" = "editor::ComposeCompletion";
  }
  {
    context = "Editor && edit_prediction";
    bindings = {
      "alt-l" = "editor::AcceptEditPrediction";
      "alt-k" = "editor::AcceptNextWordEditPrediction";
      "alt-n" = "editor::NextEditPrediction";
      "alt-p" = "editor::PreviousEditPrediction";
      "alt-'" = "editor::ToggleEditPrediction";
      "alt-j" = "editor::ShowEditPrediction";
    };
  }
  {
    # Work in normal and visual mode.
    context = "VimControl && !menu";
    bindings = {
      "ctrl-h" = "workspace::ActivatePaneLeft";
      "ctrl-l" = "workspace::ActivatePaneRight";
      "ctrl-k" = "workspace::ActivatePaneUp";
      "ctrl-j" = "workspace::ActivatePaneDown";
      "g j" = "editor::AddSelectionBelow";
      "g k" = "editor::AddSelectionAbove";
      "g n" = "vim::SelectNextMatch";
      "g shift-n" = "vim::SelectPreviousMatch";
      "g l" = "vim::SelectNext";
      "g h" = "vim::SelectPrevious";
      "g shift-l" = [
        "editor::SelectNext"
        { replace_newest = true; }
      ];
      "g shift-h" = [
        "editor::SelectPrevious"
        { replace_newest = true; }
      ];
    };
  }
  {
    context = "vim_mode == normal && !menu";
    bindings."space g g" = spawn "git";
  }
  {
    # Also work when no editor exists.
    context = "EmptyPane || SharedScreen";
    bindings."space f" = "file_finder::Toggle";
  }
]
