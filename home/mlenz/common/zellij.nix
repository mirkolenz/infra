{
  osConfig,
  config,
  lib,
  pkgs,
  ...
}:
let
  zellijExe = lib.getExe config.programs.zellij.package;

  projectRoot = "${config.home.homeDirectory}/Developer";

  layouts = [
    {
      title = "codex";
      command = "codex";
    }
    {
      title = "claude";
      command = "claude";
    }
    {
      title = "lazygit";
      command = "lazygit";
      keybind = "Alt g";
    }
    {
      title = "nvim";
      command = "nvim";
      keybind = "Alt e";
    }
  ];

  defaultTabTemplate = ''
    default_tab_template {
      pane size=1 borderless=true {
        plugin location="zellij:tab-bar"
      }
      pane split_direction="vertical" {
        pane size="18%" name="Projects" {
          plugin location="file:${pkgs.zellijPlugins.project-sidebar.wasm}" {
            scan_dir "${projectRoot}"
            session_layout "${config.xdg.configHome}/zellij/layouts/default.kdl"
            verbosity "minimal"
          }
        }
        children
      }
      pane size=1 borderless=true {
        plugin location="zellij:status-bar"
      }
    }
  '';

  mkLayoutText = l: ''
    layout {
      ${defaultTabTemplate}
      tab name="${l.title}" {
        pane command="${l.command}" close_on_exit=true
      }
    }
  '';

  layoutFiles = lib.listToAttrs (
    map (l: {
      name = l.title;
      value = pkgs.writeText "zellij-layout-${l.title}.kdl" (mkLayoutText l);
    }) layouts
  );

  mkLayoutFile = l: {
    name = "zellij/layouts/${l.title}.kdl";
    value.source = layoutFiles.${l.title};
  };

  mkKeybind =
    l:
    lib.optionalString (l ? keybind) ''
      bind "${l.keybind}" {
        NewTab { name "${l.title}"; layout "${layoutFiles.${l.title}}"; };
      }
    '';
in
{
  programs.zellij = {
    enable = true;
    # https://zellij.dev/documentation/options.html
    settings = {
      auto_layout = true;
      copy_on_select = true;
      default_layout = "default";
      default_mode = "normal";
      on_force_close = "detach";
      pane_frames = false;
      session_serialization = true;
      show_release_notes = false;
      show_startup_tips = false;
      theme = "gruvbox-dark";
      web_server = false; # managed via launchd
    };
    # https://zellij.dev/documentation/keybindings-keys.html
    # https://github.com/zellij-org/zellij/blob/main/zellij-utils/assets/config/default.kdl
    extraConfig = ''
      plugins {
        tab-bar location="zellij:tab-bar"
        status-bar location="zellij:status-bar"
        strider location="zellij:strider"
        compact-bar location="zellij:compact-bar"
        session-manager location="zellij:session-manager"
        welcome-screen location="zellij:session-manager" {
          welcome_screen true
        }
        filepicker location="zellij:strider" {
          cwd "/"
        }
        plugin-manager location="zellij:plugin-manager"
        choose-tree location="file:${pkgs.zellijPlugins.choose-tree.wasm}"
        project-sidebar location="file:${pkgs.zellijPlugins.project-sidebar.wasm}"
        sessionpicker location="file:${pkgs.zellijPlugins.choose-tree.wasm}"
        sessionizer location="file:${pkgs.zellijPlugins.sessionizer.wasm}" {
          cwd "/"
          root_dirs "${projectRoot}"
          session_layout "default"
        }
      }
      keybinds {
        shared {
          unbind "Alt f"
          bind "Alt Shift f" { ToggleFloatingPanes; }
        }
        normal {
          bind "Alt c" { Copy; }
          bind "Alt t" { NewTab; }
          bind "Alt w" { CloseTab; }
          bind "Alt s" {
            LaunchOrFocusPlugin "choose-tree" {
              floating true
              move_to_focused_tab true
              show_plugins false
            }
            SwitchToMode "Locked";
          }
          bind "Alt Shift s" {
            LaunchOrFocusPlugin "session-manager" {
              floating true
              move_to_focused_tab true
            }
          }
          bind "Alt p" {
            LaunchOrFocusPlugin "sessionizer" {
              floating true
              move_to_focused_tab true
            }
            SwitchToMode "Locked";
          }
          ${lib.concatMapStrings mkKeybind layouts}
        }
      }
    '';
  };
  xdg.configFile = lib.mkMerge [
    (lib.listToAttrs (map mkLayoutFile layouts))
    {
      "zellij/layouts/default.kdl".text = ''
        layout {
          ${defaultTabTemplate}
          tab { pane; }
        }
      '';
      "zellij/themes/flexoki.kdl".source = "${pkgs.flexoki}/share/zellij/flexoki.kdl";
    }
  ];
  home.shellAliases = {
    zj = zellijExe;
    zja = "${zellijExe} attach";
    zjx = "${zellijExe} attach --create main";
    zjw = "${zellijExe} -l welcome";
  };
  # Zellij web server
  launchd.agents.zellij-web = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = false;
    config = {
      ProgramArguments = [
        zellijExe
        "web"
        "--start"
        "--ip"
        "127.0.0.1"
        "--port"
        "8082"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Background";
      WorkingDirectory = config.home.homeDirectory;
      EnvironmentVariables = {
        HOME = config.home.homeDirectory;
        USER = config.home.username;
        SHELL = lib.getExe config.programs.fish.package;
        LANG = "en_US.UTF-8";
        TERM = "xterm-256color";
        PATH = lib.replaceStrings [ "$HOME" "$USER" ] [ config.home.homeDirectory config.home.username ] (
          osConfig.environment.systemPath or (lib.makeBinPath [ config.home.profileDirectory ])
        );
      };
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/zellij-web.out.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/zellij-web.err.log";
    };
  };
}
