{
  config,
  lib,
  pkgs,
  ...
}:
let
  zellijExe = lib.getExe config.programs.zellij.package;

  projectRoot = "${config.home.homeDirectory}/Developer";
  # Repositories live at <owner>/<repo>, so .git sits 3 levels below the root;
  # bounding the scan depth keeps project discovery fast.
  projectMaxDepth = 3;

  defaultTabTemplate = ''
    default_tab_template {
      pane size=1 borderless=true {
        plugin location="zellij:tab-bar"
      }
      children
      pane size=1 borderless=true {
        plugin location="zellij:status-bar"
      }
    }
  '';

  # Focus a named tab, recreating it (with its command) if it was closed.
  zjtab = pkgs.writeShellApplication {
    name = "zjtab";
    runtimeInputs = [ config.programs.zellij.package ];
    text = ''
      name="$1"
      shift
      # go-to-tab-name fails when the tab is gone; recreate it with its command.
      if zellij action go-to-tab-name -- "$name" 2>/dev/null; then
        exit 0
      elif [ "$#" -gt 0 ]; then
        zellij action new-tab --name "$name" -- "$@"
      else
        zellij action new-tab --name "$name"
      fi
    '';
  };

  zjide = pkgs.writeShellApplication {
    name = "zjide";
    runtimeInputs = with pkgs; [
      config.programs.zellij.package
      config.programs.zoxide.package
      coreutils
      fd
      fzf
      gawk
    ];
    text = ''
      project_root="${projectRoot}"
      if ! project_root="$(cd "$project_root" && pwd -P)"; then
        echo "Project root does not exist: $project_root" >&2
        exit 1
      fi

      if [ "$#" -gt 0 ]; then
        if ! project="$(zoxide query -- "$@")"; then
          echo "No zoxide entry found for: $*" >&2
          exit 1
        fi
      else
        # --prune stops fd from descending into each repo's .git internals,
        # --format '{//}' yields the parent directory without spawning dirname.
        projects="$(
          {
            zoxide query --list --base-dir "$project_root" 2>/dev/null || true
            fd --hidden --prune --type directory --type file '^\.git$' "$project_root" --max-depth ${toString projectMaxDepth} --format '{//}' | sort -u
          } | awk '!seen[$0]++'
        )"

        if [ -z "$projects" ]; then
          echo "No Git repositories found under $project_root" >&2
          exit 1
        fi

        project="$(fzf --no-sort --prompt="project> " --height=100% --layout=reverse --border=none <<<"$projects")"
        if [ -z "$project" ]; then
          exit 0
        fi
      fi

      # Strip the root prefix when nested, otherwise fall back to the basename;
      # both use parameter expansion to avoid spawning basename.
      case "$project" in
        "$project_root"/*) relative="''${project#"$project_root"/}" ;;
        *) relative="''${project##*/}" ;;
      esac

      # Replace each '/', ' ' and '.' with '-' for a valid session name.
      session_name="''${relative//[\/ .]/-}"
      if [ -n "''${ZELLIJ:-}" ]; then
        exec zellij action switch-session --cwd "$project" --layout ide "$session_name"
      fi

      cd "$project"
      exec zellij --session "$session_name" --new-session-with-layout ide
    '';
  };
in
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
    layouts.ide = ''
      layout {
        ${defaultTabTemplate}
        tab name="edit" focus=true {
          pane command="nvim"
          close_on_exit true
        }
        tab name="files" {
          pane command="yazi"
          close_on_exit true
        }
        tab name="git" {
          pane command="lazygit"
          close_on_exit true
        }
        tab name="shell" {
          pane
          close_on_exit true
        }
      }
    '';
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
          unbind "Alt f"
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
          bind "Alt e" {
            Run "${lib.getExe zjtab}" "editor" "nvim" {
              floating true
              close_on_exit true
            };
          }
          bind "Alt f" {
            Run "${lib.getExe zjtab}" "files" "yazi" {
              floating true
              close_on_exit true
            };
          }
          bind "Alt g" {
            Run "${lib.getExe zjtab}" "git" "lazygit" {
              floating true
              close_on_exit true
            };
          }
          bind "Alt o" {
            Run "${lib.getExe zjtab}" "shell" {
              floating true
              close_on_exit true
            };
          }
          bind "Alt p" {
            Run "${lib.getExe zjide}" {
              floating true
              name "zjide"
              close_on_exit true
            }
          }
        }
      }
    '';
  };

  home.packages = [
    zjide
  ];

  home.shellAliases = {
    zj = zellijExe;
    zja = "${zellijExe} attach";
    zjx = "${zellijExe} attach --create main";
  };
}
