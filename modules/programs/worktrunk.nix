{
  flake.modules.homeManager.default =
    { config, lib, ... }:
    lib.mkIf config.programs.agents.enable {
      # `claudeCodeIntegration` stays off, since nono confines claude and its hooks to the
      # working directory. The worktree hooks and `/wt-switch-create` would create sibling
      # worktrees outside of it, and the activity markers are written to the read-only
      # `.git/config`. Worktrees are created by `wt switch --create --execute claude` instead,
      # which starts the agent within the new worktree.
      # https://worktrunk.dev/config/
      programs.worktrunk = {
        enable = true;
        settings = {
          skip-shell-integration-prompt = true;
          commit.generation = {
            # https://worktrunk.dev/llm-commits/
            command = "MAX_THINKING_TOKENS=0 claude -p --no-session-persistence --model=haiku --tools='' --safe-mode --setting-sources='user' --system-prompt=''";
            # mirrors the message format of the my-commit skill
            template-append = ''
              - Use a conventional message `<type>(<scope>): <title>` with a concise title and an empty body
              - Reuse the scopes of the recent commits
            '';
          };
        };
      };
      programs.agents.sandbox.paths = {
        # read by `wt` within the sandbox, holding the approvals of the project hooks as well
        "${config.xdg.configHome}/worktrunk" = "read";
        # project hooks that `wt` runs outside the sandbox later
        ".config/wt.toml" = "read";
      };
    };
}
