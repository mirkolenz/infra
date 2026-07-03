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
          tools = {
            ask_user_question.permission = "always";
            grep.permission = "always";
            read_file.permission = "always";
            search_replace.permission = "always";
            skill.permission = "always";
            task.permission = "ask";
            todo.permission = "always";
            web_fetch.permission = "always";
            web_search.permission = "always";
            write_file.permission = "always";
            bash = {
              permission = "ask";
              allowlist = [
                "cat"
                "cd"
                "echo"
                "file"
                "find"
                "gh"
                "git diff"
                "git log"
                "git status"
                "grep"
                "head"
                "jq"
                "ls"
                "nix"
                "pwd"
                "rg"
                "stat"
                "tail"
                "tree"
                "uname"
                "wc"
                "which"
                "whoami"
              ];
            };
          };
        };
      };
    };
}
