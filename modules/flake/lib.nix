# `flake.lib`: the helpers of flocken merged with the ones of this flake. It is
# also the `lib'` argument of the flake-parts modules, which modules/core passes
# on to the option modules under options/, and helpers refer to each other through it.
{
  self,
  inputs,
  lib,
  lib',
  config,
  ...
}:
{
  _module.args.lib' = config.flake.lib;

  flake.lib = inputs.flocken.lib // {
    # A value home-manager links rather than writes.
    inherit (inputs.home-manager.lib.hm.strings) isPathLike;

    # `home.file` entry for the value of an agent option that is either content or a
    # file to link, the way the claude-code, codex, and opencode modules read theirs.
    # https://github.com/nix-community/home-manager/blob/master/modules/programs/claude-code/lib.nix
    mkAgentFile =
      content: if lib'.isPathLike content then { source = content; } else { text = content; };

    # `home.file` entries placing the value of `programs.agents.skills` in `dir`. A
    # directory is linked as a whole, an attribute set becomes one entry per skill,
    # where a directory or a derivation building one is again linked as a whole and
    # everything else is the skill's `SKILL.md`. Both stay real directories, which lets an
    # agent write its own skills next to the managed ones. A store path that is only a
    # string is taken for a file, because telling it apart from a directory needs a
    # builder, as upstream does it.
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
          if lib.isDerivation content || lib.isPath content && lib.pathIsDirectory content then
            {
              "${dir}/${name}" = {
                source = content;
                recursive = true;
              };
            }
          else
            { "${dir}/${name}/SKILL.md" = lib'.mkAgentFile content; }
        ) skills;

    # Symlink a file to its live location in the checked-out config repo
    # (`config.custom.configPath`) rather than the read-only store, so edits take
    # effect without a rebuild. `value` is a path within this repo; its prefix
    # relative to the repo root is reused under the checkout.
    # https://github.com/ncfavier/config/blob/bfc59fe3febc7a389105d05141215ca725bf7a9f/modules/nix.nix#L64-L68
    mkMutableSymlink =
      { config, value }:
      config.lib.file.mkOutOfStoreSymlink (
        config.custom.configPath + lib.removePrefix (toString self) (toString value)
      );

    # nixvim keymap running `action` as a command, or as lua when `raw`.
    mkVimKeymap =
      {
        raw,
        prefix ? "",
        suffix ? "",
        mode ? "n",
      }:
      attrs:
      attrs
      // {
        action =
          if raw then
            { __raw = "function() ${prefix}${attrs.action}${suffix} end"; }
          else
            "<cmd>${prefix}${attrs.action}${suffix}<CR>";
        mode = attrs.mode or mode;
      };
    mkVimKeymaps = opts: values: map (lib'.mkVimKeymap opts) values;
  };
}
