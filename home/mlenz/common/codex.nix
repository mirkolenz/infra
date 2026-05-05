{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.custom.features.withOptionals {
  programs.codex = {
    enable = true;
    package = pkgs.codex-bin;
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
          ":project_roots" = {
            "." = "write";
            ".git" = "read";
          };
          ":tmpdir" = "write";
          "/tmp" = "write";
          "/nix" = "write";
          "${config.home.homeDirectory}/.npm" = "write";
          "${config.home.homeDirectory}/Library/Caches" = "write";
          "${config.xdg.cacheHome}" = "write";
          "${config.xdg.configHome}/.wrangler/logs" = "write";
        };
        network = {
          enabled = true;
          mode = "limited";
          allow_local_binding = true;
          unix_sockets = {
            "/nix/var/nix/daemon-socket/socket" = "allow";
          };
        };
      };
      tools = {
        view_image = true;
        web_search = { };
      };
      tui = {
        alternate_screen = "never";
        notifications = true;
      };
      shell_environment_policy = {
        set = {
          ASTRO_TELEMETRY_DISABLED = "1";
        };
      };
      # codex features list
      # https://github.com/openai/codex/blob/main/codex-rs/features/src/lib.rs
      features = {
        js_repl = true;
        prevent_idle_sleep = true;
      };
    };
  };
}
