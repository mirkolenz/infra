{
  flake.modules.homeManager.default =
    {
      config,
      lib,
      lib',
      pkgs,
      ...
    }:
    let
      agents = config.programs.agents;
      package = config.programs.codex.package;
    in
    lib.mkIf config.custom.features.extras.enable {
      programs.codex = {
        enable = true;
        package = pkgs.codex-bin;
        enableMcpIntegration = true;
        inherit (agents) context skills;
        # https://developers.openai.com/codex/config-reference
        # https://developers.openai.com/codex/config-schema.json
        settings = {
          model = "gpt-6-sol";
          model_reasoning_effort = "xhigh";
          model_verbosity = "low";
          # counterpart to Claude's `allowUnsandboxedCommands = false`
          approval_policy.granular = {
            sandbox_approval = false;
            mcp_elicitations = true;
            rules = true;
            request_permissions = true;
            skill_approval = true;
          };
          approvals_reviewer = "auto_review";
          file_opener = "none";
          check_for_update_on_startup = false;
          web_search = "live";
          service_tier = "default";
          forced_login_method = "chatgpt";
          memories = {
            generate_memories = false;
            use_memories = false;
          };
          # https://developers.openai.com/codex/permissions
          default_permissions = "workspace-net";
          permissions.workspace-net = {
            # :workspace grants writable workspace roots, read-only .git/.codex within
            # them, :minimal read access, and write to :tmpdir and :slash_tmp (/tmp).
            extends = ":workspace";
            filesystem = {
              ":workspace_roots" = {
                ".git" = "write";
              };
              # tool state codex reads that the other agents reach through their
              # broader default read access
              "${config.xdg.configHome}/gh" = "read";
              "${config.xdg.configHome}/git" = "read";
              "${config.xdg.configHome}/uv" = "read";
            }
            # deny wins over the read granted by :workspace, keeping ssh keys unreadable
            // agents.sandbox.paths;
            network = {
              enabled = true;
              allow_local_binding = true;
              # Codex has no counterpart to claude's `strictAllowlist`: the one switch that
              # would let it ask for a host beyond this list is `sandbox_approval`, which
              # also reopens `require_escalated`, so the list stays the whole boundary.
              domains =
                lib.genAttrs agents.sandbox.allowedDomains (_: "allow")
                // lib.genAttrs agents.sandbox.deniedDomains (_: "deny");
              unix_sockets = lib.genAttrs agents.sandbox.allowedUnixSockets (_: "allow");
            };
          };
          tui = {
            notifications = true;
            vim_mode_default = false;
            alternate_screen = "always";
            show_tooltips = false;
            fullscreen_transcript = true;
          };
          notice = {
            hide_rate_limit_model_nudge = true;
          };
          shell_environment_policy = {
            filters = lib.genAttrs agents.sandbox.deniedEnvVars (_: "exclude");
            set = agents.sandbox.sessionVariables;
          };
          desktop = {
            followUpQueueMode = "queue";
            show-context-window-usage = true;
            hotkey-window-projectless-default-enabled = true;
            appearanceDarkCodeThemeId = "codex";
            appearanceLightCodeThemeId = "codex";
            usePointerCursors = false;
            git-pull-request-merge-method = "squash";
            mac-menu-bar-enabled = false;
            open-in-target-preferences.global = "zed";
            composerPlainTextMode = true;
            enabled-reasoning-efforts = [
              "low"
              "medium"
              "high"
              "xhigh"
              "ultra"
              "max"
            ];
          };
        };
      };
      # Codex writes trust decisions back to config.toml, which fails on a read-only
      # store symlink (https://github.com/openai/codex/issues/6646). Replace it with a
      # writable copy of the generated config; trust resets on each activation.
      home.file.".codex/config.toml".enable = lib.mkForce false;

      home.activation.setupCodexFiles = lib'.mkMutableFile {
        inherit config;
        source = config.home.file.".codex/config.toml".source;
        target = "${config.home.homeDirectory}/.codex/config.toml";
      };

      # The app-server daemon runs whatever package `current` selects and only installs
      # a copy when it is missing. A store path also keeps its self-updater disabled.
      home.file.".codex/packages/app-server-daemon/current" = {
        source = "${package}/libexec/codex";
        # A running daemon keeps its old binary until restarted.
        onChange = /* bash */ ''
          if [[ -e "$HOME/.codex/app-server-daemon/daemon.pid" ]]; then
            run ${lib.getExe package} app-server daemon restart \
              || warnEcho "Failed to restart the codex app-server daemon"
          fi
        '';
      };
    };
}
