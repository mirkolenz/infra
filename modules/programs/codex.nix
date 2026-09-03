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
      codexHomes = [
        ".codex"
        ".codex-api"
      ];
    in
    lib.mkIf config.custom.features.extras.enable {
      programs.codex = {
        enable = true;
        package = pkgs.codex-bin;
        enableMcpIntegration = true;
        # https://developers.openai.com/codex/config-reference
        # https://developers.openai.com/codex/config-schema.json
        settings = {
          model = "gpt-5.6-sol";
          model_reasoning_effort = "high";
          plan_mode_reasoning_effort = "high";
          approval_policy = "on-request";
          approvals_reviewer = "auto_review";
          file_opener = "none";
          check_for_update_on_startup = false;
          personality = "pragmatic";
          web_search = "live";
          service_tier = "default";
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
              "/nix" = "read";
              "${config.home.homeDirectory}/.npm" = "write";
              "${config.home.homeDirectory}/Library/Caches" = "write";
              "${config.xdg.cacheHome}" = "write";
              "${config.xdg.configHome}/gh" = "read";
              "${config.xdg.configHome}/git" = "read";
              "${config.xdg.configHome}/uv" = "read";
              "${config.xdg.configHome}/.wrangler/logs" = "write";
              # deny wins over the read granted by :workspace, keeping ssh keys unreadable
              "${config.home.homeDirectory}/.ssh" = "deny";
            }
            # orb stores logs, sockets, and state here and reads them on every call, darwin only
            // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
              "${config.home.homeDirectory}/.orbstack" = "write";
            };
            network = {
              enabled = true;
              allow_local_binding = true;
              domains = {
                "github.com" = "allow";
                "api.github.com" = "allow";
                "raw.githubusercontent.com" = "allow";
                # "pypi.org" = "allow";
                # "files.pythonhosted.org" = "allow";
                # "huggingface.co" = "allow";
                # "registry.npmjs.org" = "allow";
                # "api.npmjs.org" = "allow";
                # "ui.shadcn.com" = "allow";
              };
              unix_sockets = {
                ${lib'.nixDaemonSocket pkgs.stdenv} = "allow";
              }
              # orb talks to the OrbStack daemon over the sockets under this dir, darwin only
              // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
                "${config.home.homeDirectory}/.orbstack/run" = "allow";
              };
            };
          };
          tui = {
            notifications = true;
            vim_mode_default = false;
            alternate_screen = "auto";
            show_tooltips = false;
          };
          notice = {
            hide_rate_limit_model_nudge = true;
          };
          shell_environment_policy = {
            # drop the agent socket so ssh cannot authenticate via a forwarded agent
            filters.SSH_AUTH_SOCK = "exclude";
            set = {
              ASTRO_TELEMETRY_DISABLED = "1";
              # determinate-nix spawns a sentry crashpad_handler that cannot register its
              # mach bootstrap port inside the sandbox, so disable it to avoid stderr noise
              NIX_SENTRY_ENDPOINT = "";
            };
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

      # Codex keeps auth.json, history and sessions inside CODEX_HOME, so a second
      # home is the only way to hold a chatgpt login and an api-key login at once.
      # Both homes receive the same generated config, leaving only state divergent.
      home.file.".codex-api/AGENTS.md".text = config.programs.agents.instructions.text;

      home.activation.setupCodexFiles = lib'.mkMutableFiles {
        inherit config;
        files = map (dir: {
          source = config.home.file.".codex/config.toml".source;
          target = "${config.home.homeDirectory}/${dir}/config.toml";
        }) codexHomes;
      };

      home.shellAliases.codex-api = "env CODEX_HOME=${config.home.homeDirectory}/.codex-api codex";
    };
}
