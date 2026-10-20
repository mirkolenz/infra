# Helpers placing the files of the coding agents.
{
  inputs,
  lib,
  lib',
  ...
}:
{
  flake.lib = {
    # A value home-manager links rather than writes.
    inherit (inputs.home-manager.lib.hm.strings) isPathLike;

    # `home.file` entry for the value of an agent option that is either content or a
    # file to link, the way the claude-code, codex, and opencode modules read theirs.
    # https://github.com/nix-community/home-manager/blob/master/modules/programs/claude-code/lib.nix
    mkAgentFile =
      content: if lib'.isPathLike content then { source = content; } else { text = content; };

    # `home.file` entries placing the value of `programs.agents.skills` in `dir`. A
    # directory is linked as a whole, an attribute set becomes one entry per skill,
    # where a directory is again linked as a whole and everything else is the skill's
    # `SKILL.md`. Both stay real directories, which lets an agent write its own skills
    # next to the managed ones. A store path that is only a string is taken for a file,
    # because telling it apart from a directory needs a builder, as upstream does it.
    # https://github.com/nix-community/home-manager/blob/master/modules/programs/claude-code/lib.nix
    mkAgentSkills =
      dir: skills:
      if lib'.isPathLike skills then
        {
          ${dir} = {
            source = skills;
            recursive = true;
          };
        }
      else
        lib.concatMapAttrs (
          name: content:
          if lib.isPath content && lib.pathIsDirectory content then
            {
              "${dir}/${name}" = {
                source = content;
                recursive = true;
              };
            }
          else
            { "${dir}/${name}/SKILL.md" = lib'.mkAgentFile content; }
        ) skills;
  };
}
