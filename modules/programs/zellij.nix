{
  flake.modules.homeManager.default =
    { ... }:
    {
      programs.zellij = {
        enable = true;
        # https://zellij.dev/documentation/options.html
        settings = {
          auto_layout = true;
          copy_on_select = true;
          default_mode = "normal";
          on_force_close = "detach";
          pane_frames = false;
          session_serialization = false;
          show_release_notes = false;
          show_startup_tips = false;
          theme = "gruvbox-dark";
          web_server = false;
        };
        # https://zellij.dev/documentation/keybindings-keys.html
        # https://zellij.dev/documentation/keybindings-possible-actions.html
        extraConfig = ''
          plugins {
            tab-bar location="zellij:tab-bar"
            status-bar location="zellij:status-bar"
            session-manager location="zellij:session-manager"
          }
          keybinds {
            shared {
              bind "Alt Shift f" { ToggleFloatingPanes; }
            }
            normal {
              bind "Alt c" { Copy; }
              bind "Alt t" {
                NewTab;
                SwitchToMode "RenameTab";
                TabNameInput 0;
              }
              bind "Alt w" { CloseTab; }
              bind "Alt s" {
                LaunchOrFocusPlugin "session-manager" {
                  floating true
                  move_to_focused_tab true
                }
              }
            }
          }
        '';
      };

      home.shellAliases = {
        zj = "zellij";
        zjm = "zellij attach --create main";
      };
    };
}
