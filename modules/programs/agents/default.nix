{
  flake.modules.homeManager.default =
    { lib, ... }:
    {
      programs.agents = {
        enable = true;
        instructions.source = ./AGENTS.md;
        # Every subdirectory holding a SKILL.md is a skill, named after the directory.
        # These are Claude Code built-in prompts, reflowed to one sentence per line:
        # `smpl` is /simplify (anchor `4 cleanup agents in parallel`) and `rvw` is
        # /code-review at xhigh effort on Opus 5 (anchor `10 inline angles`).
        # To refresh after an upgrade, ask Claude to re-extract them from its own
        # bundle using those anchors, then diff against the text here.
        # Keep the descriptions free of proactive triggers: upstream ships these as
        # slash commands, so its wording invites unprompted use.
        skills = lib.concatMapAttrs (
          name: _:
          lib.optionalAttrs (lib.pathExists (./. + "/${name}/SKILL.md")) {
            ${name}.source = ./. + "/${name}";
          }
        ) (lib.readDir ./.);
      };
    };
}
