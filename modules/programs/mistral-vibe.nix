{
  flake.modules.homeManager.default =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    lib.mkIf config.custom.features.extras.enable {
      programs.mistral-vibe = {
        enable = false;
        package = pkgs.mistral-vibe;
        # Upstream references (pinned to the version in flake.nix; bump together):
        # https://github.com/mistralai/mistral-vibe/blob/main/README.md
        # https://github.com/mistralai/mistral-vibe/blob/main/vibe/core/config/_settings.py
        # https://github.com/mistralai/mistral-vibe/tree/main/vibe/core/tools/builtins
        # https://github.com/mistralai/mistral-vibe/blob/main/vibe/core/tools/base.py
        # https://github.com/mistralai/mistral-vibe/blob/main/vibe/core/agents/models.py
        settings = {
          active_model = "mistral-medium-3.5";
          enable_auto_update = false;
          enable_notifications = true;
          enable_telemetry = false;
          enable_update_checks = false;
          disable_welcome_banner_animation = true;
          # Permission values: "always" | "ask" | "never" (vibe/core/tools/base.py::ToolPermission).
          # Each tool's full config schema lives at vibe/core/tools/builtins/<name>.py::*Config.
          # Only tools whose upstream default differs are listed. bash keeps its ASK
          # default and upstream's own read-only allowlist, which setting `allowlist`
          # here would replace rather than extend.
          tools = {
            search_replace.permission = "always";
            # web_fetch and web_search ignore allowlist/denylist/sensitive_patterns,
            # so the flat permission level is the only available gate.
            web_fetch.permission = "always";
            web_search.permission = "always";
            write_file.permission = "always";
          };
        };
      };
    };
}
