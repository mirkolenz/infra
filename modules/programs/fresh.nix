{
  flake.modules.homeManager.default =
    { pkgs, ... }:
    {
      programs.fresh-editor = {
        enable = true;
        package = pkgs.fresh-editor-bin;
        settings = {
          theme = "builtin://dark";
          check_for_updates = false;
          active_keybinding_map = "vscode";
          file_browser = {
            show_hidden = true;
          };
          file_explorer = {
            show_hidden = true;
          };
          editor = {
            completion_popup_auto_show = true;
            enable_semantic_tokens_full = true;
            ensure_final_newline_on_save = true;
            indentation_guide = "all";
            nerd_font_icons = true;
            trim_trailing_whitespace_on_save = true;
          };
          plugins = {
            git_explorer.settings.colorNames = true;
          };
        };
      };
    };
}
