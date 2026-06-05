{
  flake.modules.nixvim.default =
    {
      lib',
      lib,
      config,
      ...
    }:
    {
      plugins.multiple-cursors = {
        enable = false;
      };
      keymaps = lib.mkIf config.plugins.multiple-cursors.enable (
        lib'.mkVimKeymaps
          {
            prefix = "MultipleCursors";
            raw = false;
          }
          [
            {
              key = "gk";
              mode = [
                "n"
                "x"
              ];
              action = "MultipleCursorsAddUp";
              options.desc = "Add cursor and move up";
            }
            {
              key = "gj";
              mode = [
                "n"
                "x"
              ];
              action = "MultipleCursorsAddDown";
              options.desc = "Add cursor and move down";
            }
            {
              key = "gl";
              mode = [
                "n"
                "x"
              ];
              action = "AddJumpNextMatch";
              options.desc = "Add cursor and jump to next cword";
            }
            {
              key = "gh";
              mode = [
                "n"
                "x"
              ];
              action = "AddJumpPrevMatch";
              options.desc = "Add cursor and jump to previous cword";
            }
            {
              key = "gL";
              mode = [
                "n"
                "x"
              ];
              action = "MultipleCursorsAddMatches";
              options.desc = "Add cursors to cword";
            }
            {
              key = "gH";
              mode = [
                "n"
                "x"
              ];
              action = "MultipleCursorsAddMatchesV";
              options.desc = "Add cursors to cword in previous area";
            }
            {
              key = "<M-leftmouse>";
              mode = [
                "n"
                "i"
              ];
              action = "MouseAddDelete";
              options.desc = "Add or remove cursor";
            }
          ]
      );
    };
}
