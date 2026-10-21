# Fresh, whose language servers and formatters come from options/home-manager/fresh.nix.
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
          keybindings = [
            {
              key = "o";
              modifiers = [ "ctrl" ];
              action = "quick_open_files";
              when = "global";
            }
            {
              key = "a";
              modifiers = [ "ctrl" ];
              action = "select_all";
              when = "normal";
            }
          ];
          file_browser = {
            show_hidden = true;
          };
          file_explorer = {
            show_hidden = true;
            show_gitignored = true;
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
