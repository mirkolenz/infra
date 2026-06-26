{
  flake.modules.homeManager.default =
    {
      config,
      lib,
      lib',
      pkgs,
      ...
    }:
    lib.mkIf config.custom.features.withOptionals {
      programs.codex = {
        enable = true;
        package = pkgs.codex-bin;
        enableMcpIntegration = true;
        # https://developers.openai.com/codex/config-reference
        # https://developers.openai.com/codex/config-schema.json
        settings = {
          model = "gpt-5.5";
          commit_attribution = "";
          model_reasoning_effort = "xhigh";
          plan_mode_reasoning_effort = "xhigh";
          approval_policy = "on-request";
          approvals_reviewer = "auto_review";
          file_opener = "none";
          preferred_auth_method = "chatgpt";
          check_for_update_on_startup = false;
          personality = "pragmatic";
          web_search = "live";
          default_permissions = "default";
          permissions.default = {
            filesystem = {
              ":minimal" = "read";
              ":workspace_roots" = {
                "." = "write";
                ".git" = "read";
              };
              ":tmpdir" = "write";
              "/tmp" = "write";
              "/nix" = "write";
              "${config.home.homeDirectory}/.npm" = "write";
              "${config.home.homeDirectory}/Library/Caches" = "write";
              "${config.xdg.cacheHome}" = "write";
              "${config.xdg.configHome}/git" = "read";
              "${config.xdg.configHome}/.wrangler/logs" = "write";
            }
            # orb stores logs, sockets, and state here and reads them on every call, darwin only
            // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
              "${config.home.homeDirectory}/.orbstack" = "write";
            };
            network = {
              enabled = true;
              mode = "limited";
              allow_local_binding = true;
              domains = {
                "github.com" = "allow";
                "api.github.com" = "allow";
                "raw.githubusercontent.com" = "allow";
                "pypi.org" = "allow";
                "files.pythonhosted.org" = "allow";
                "huggingface.co" = "allow";
                "registry.npmjs.org" = "allow";
                "api.npmjs.org" = "allow";
                "ui.shadcn.com" = "allow";
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
          tools = {
            view_image = true;
            web_search = { };
          };
          tui = {
            notifications = true;
            vim_mode_default = false;
          };
          notice = {
            hide_rate_limit_model_nudge = true;
          };
          shell_environment_policy = {
            set = {
              ASTRO_TELEMETRY_DISABLED = "1";
              # determinate-nix spawns a sentry crashpad_handler that cannot register its
              # mach bootstrap port inside the sandbox, so disable it to avoid stderr noise
              NIX_SENTRY_ENDPOINT = "";
            };
          };
          # codex features list
          # https://github.com/openai/codex/blob/main/codex-rs/features/src/lib.rs
          features = {
            fast_mode = false;
            memories = false;
            prevent_idle_sleep = true;
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
    };
}
