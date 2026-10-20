# Helpers for nixvim keymaps.
{ lib', ... }:
{
  flake.lib = {
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
