{
  flake.modules.homeManager.default =
    {
      config,
      pkgs,
      lib,
      lib',
      ...
    }:
    let
      agents = config.programs.agents;
      cfg = config.programs.mistral-vibe;
    in
    lib.mkIf config.programs.agents.enable {
      programs.mistral-vibe = {
        enable = false;
        package = pkgs.mistral-vibe;
        # Upstream references, pinned to the packaged version (bump together):
        # https://github.com/mistralai/mistral-vibe/blob/v2.25.0/README.md
        # https://github.com/mistralai/mistral-vibe/blob/v2.25.0/vibe/core/config/vibe_schema.py
        # https://github.com/mistralai/mistral-vibe/tree/v2.25.0/vibe/core/tools/builtins
        # https://github.com/mistralai/mistral-vibe/blob/v2.25.0/vibe/core/tools/base.py
        # https://github.com/mistralai/mistral-vibe/blob/v2.25.0/vibe/core/tools/utils.py
        # https://github.com/mistralai/mistral-vibe/blob/v2.25.0/vibe/core/hooks/models.py
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
            edit.permission = "always";
            # web_fetch and web_search ignore allowlist/denylist/sensitive_patterns,
            # so the flat permission level is the only available gate.
            web_fetch.permission = "always";
            web_search.permission = "always";
            write_file.permission = "always";
          };
        };
      };
      # Vibe reads its global context from `VIBE_HOME/AGENTS.md` and user-level skills
      # from `VIBE_HOME/skills`, neither of which its home-manager module can express
      # yet, so both are wired the way the claude-code, codex, and opencode modules wire
      # their own. `skills/` stays a real directory either way, which is what lets vibe
      # write the entries of `vibe skill install` next to the managed ones.
      home.file = lib.mkIf cfg.enable (
        {
          ".vibe/AGENTS.md" = lib.mkIf (agents.context != "") (lib'.mkAgentFile agents.context);
        }
        // lib'.mkAgentSkills ".vibe/skills" agents.skills
      );
      programs.agents = {
        harnesses.vibe = lib.mkIf cfg.enable {
          launchers.vibe = cfg.package;
          addDirFlag = "--add-dir";
          # the API key is kept in `.vibe/.env`
          stateDirs = [ "${config.home.homeDirectory}/.vibe" ];
          # the hooks run outside of nono
          protectedEntries = [
            "AGENTS.md"
            "config.toml"
            "hooks.toml"
            "skills"
          ];
          domains = [ "api.mistral.ai" ];
        };
        # The project config applies to other agents as well, and its hooks run outside of nono.
        # The prompts stay writable.
        sandbox.paths = {
          ".vibe" = "read";
          ".vibe/prompts" = "write";
          ".vibe/skills" = "write";
        };
      };
    };
}
