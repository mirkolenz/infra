{
  osConfig,
  config,
  lib,
  pkgs,
  ...
}:
let
  zellijExe = lib.getExe config.programs.zellij.package;

  plugins = {
    zellij-tab-name = pkgs.fetchurl {
      url = "https://github.com/Cynary/zellij-tab-name/releases/download/v0.4.2/zellij-tab-name.wasm";
      hash = "sha256:4edf6bacc00a2fe77ac464c86975c7cc77f9cbfd494c36fdc2b81b226e29e0e6";
    };
    zellij-vertical-tabs = pkgs.fetchurl {
      url = "https://github.com/cfal/zellij-vertical-tabs/releases/download/v0.1.0/zellij-vertical-tabs.wasm";
      hash = "sha256:531091b56ab3bc0008bd14de19f71985e3ab8585110ee021ef8ee413556202a2";
    };
    zjstatus = pkgs.fetchurl {
      url = "https://github.com/dj95/zjstatus/releases/download/v0.23.0/zjstatus.wasm";
      hash = "sha256:e006901223524239db618021e4cc5d17f82dc4bfae5432895ba41f03f13861ff";
    };
    zjframes = pkgs.fetchurl {
      url = "https://github.com/dj95/zjstatus/releases/download/v0.23.0/zjframes.wasm";
      hash = "sha256:8d89e831bde195363faa5a810b04460a421006d37c9886ce9e255130fa93a085";
    };
  };

  layouts = [
    {
      title = "codex";
      command = "codex";
      icon = "💻";
    }
    {
      title = "claude";
      command = "claude";
      icon = "💻";
    }
    {
      title = "lazygit";
      command = "lazygit";
      icon = "🔍";
      keybind = "Alt g";
    }
    {
      title = "nvim";
      command = "nvim";
      icon = "📝";
      keybind = "Alt e";
    }
  ];

  # pane split_direction="vertical" {
  #   pane size=18 borderless=true {
  #     plugin location="file:${plugins.zellij-vertical-tabs}"
  #   }
  #   children
  # }
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

  mkLayoutFile = l: {
    name = "zellij/layouts/${l.title}.kdl";
    value.text = ''
      layout {
        ${defaultTabTemplate}
        tab name="${l.icon} ${l.title}" {
          pane command="${l.command}" close_on_exit=true
        }
      }
    '';
  };

  mkKeybind =
    l:
    lib.optionalString (l ? keybind) ''
      bind "${l.keybind}" {
        NewTab { name "${l.icon} ${l.title}"; layout "${l.title}"; };
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
      session_serialization = false;
      show_release_notes = false;
      show_startup_tips = false;
      theme = "gruvbox-dark";
      web_server = false; # managed via launchd
    };
    # https://zellij.dev/documentation/keybindings-keys.html
    # https://github.com/zellij-org/zellij/blob/main/zellij-utils/assets/config/default.kdl
    extraConfig = ''
      load_plugins {
        "file:${plugins.zellij-tab-name}"
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
  };
  home.packages = [
    (pkgs.writeShellApplication {
      name = "zjpwd";
      text = /* bash */ ''
        parent="$(basename "$(dirname "$PWD")")"
        current="$(basename "$PWD")"
        exec ${zellijExe} attach --create "$parent-$current"
      '';
    })
    (pkgs.writeShellApplication {
      name = "zjz";
      text = /* bash */ ''
        cd "$(${lib.getExe config.programs.zoxide.package} query -- "$1")" || exit 1
        exec zjpwd
      '';
    })
  ];
  programs.fish.interactiveShellInit = ''
    if set -q ZELLIJ
      function fish_title; end

      # Use the zellij-tab-name plugin so renames target this pane's tab
      # rather than whichever tab is currently focused.
      function _zellij_rename_tab
        set -l payload (${lib.getExe pkgs.jq} -nc \
          --arg id "$ZELLIJ_PANE_ID" \
          --arg name "$argv" \
          '{pane_id: $id, name: $name}')
        command zellij pipe --name change-tab-name -- "$payload" 2>/dev/null
      end

      function _zellij_set_tab_to_cwd \
          --on-event fish_prompt \
          --on-event fish_postexec \
          --on-variable PWD
        _zellij_rename_tab "📁 "(string replace -- $HOME '~' $PWD | path basename)
      end

      function _zellij_set_tab_to_cmd --on-event fish_preexec
        set -l words (string split -n ' ' -- $argv[1])
        if test "$words[1]" = sudo
          set words $words[2..]
        end
        _zellij_rename_tab "🚀 $words[1]"
      end
    end
  '';
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
