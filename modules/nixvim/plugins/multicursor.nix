{
  flake.modules.nixvim.default =
    {
      lib',
      lib,
      config,
      ...
    }:
    {
      plugins.multicursor-nvim = {
        enable = true;
        keymapsLayer = [
          # Select a different cursor as the main one
          {
            key = "<left>";
            mode = [
              "n"
              "x"
            ];
            action = "prevCursor";
          }
          {
            key = "<right>";
            mode = [
              "n"
              "x"
            ];
            action = "nextCursor";
          }
          # Delete the main cursor
          {
            key = "<leader>x";
            mode = [
              "n"
              "x"
            ];
            action = "deleteCursor";
          }
          {
            # Enable and clear cursors using escape
            key = "<esc>";
            mode = "n";
            action = lib.nixvim.mkRaw /* lua */ ''
              mc = require('multicursor-nvim')
              if not mc.cursorsEnabled() then
                mc.enableCursors()
              else
                mc.clearCursors()
              end
            '';
          }
        ];
      };
      keymaps = lib.mkIf config.plugins.multicursor-nvim.enable (
        lib'.mkVimKeymaps
          {
            prefix = "require('multicursor-nvim').";
            raw = true;
          }
          [
            {
              key = "<C-q>";
              mode = [
                "n"
                "x"
              ];
              action = "toggleCursor()";
              options.desc = "Toggle multicursor";
            }
            {
              key = "ga";
              mode = [
                "n"
                "x"
              ];
              action = "matchAllAddCursors()";
              options.desc = "Add all matching cursors";
            }
            {
              key = "gA";
              mode = [
                "n"
                "x"
              ];
              action = "alignCursors()";
              options.desc = "Align cursor columns";
            }
            {
              key = "g;";
              mode = [
                "n"
                "x"
              ];
              action = "addCursorOperator()";
              options.desc = "Add cursor using vim operator (e.g., g;ip for all lines in a paragraph)";
            }
            # Add or skip cursor above/below the main cursor
            {
              key = "gk";
              mode = [
                "n"
                "x"
              ];
              action = "lineAddCursor(-1)";
              options.desc = "Add cursor above";
            }
            {
              key = "gj";
              mode = [
                "n"
                "x"
              ];
              action = "lineAddCursor(1)";
              options.desc = "Add cursor below";
            }
            {
              key = "gK";
              mode = [
                "n"
                "x"
              ];
              action = "lineSkipCursor(-1)";
              options.desc = "Skip cursor above";
            }
            {
              key = "gJ";
              mode = [
                "n"
                "x"
              ];
              action = "lineSkipCursor(1)";
              options.desc = "Skip cursor below";
            }
            # Add or skip adding a new cursor by matching word/selection
            {
              key = "gl";
              mode = [
                "n"
                "x"
              ];
              action = "matchAddCursor(1)";
              options.desc = "Add next matching cursor";
            }
            {
              key = "gh";
              mode = [
                "n"
                "x"
              ];
              action = "matchAddCursor(-1)";
              options.desc = "Add previous matching cursor";
            }
            {
              key = "gL";
              mode = [
                "n"
                "x"
              ];
              action = "matchSkipCursor(1)";
              options.desc = "Skip next matching cursor";
            }
            {
              key = "gH";
              mode = [
                "n"
                "x"
              ];
              action = "matchSkipCursor(-1)";
              options.desc = "Skip previous matching cursor";
            }
            {
              key = "gn";
              mode = [
                "n"
                "x"
              ];
              action = "searchAddCursor(1)";
              options.desc = "Add next search cursor";
            }
            {
              key = "gN";
              mode = [
                "n"
                "x"
              ];
              action = "searchAddCursor(-1)";
              options.desc = "Add previous search cursor";
            }
            {
              key = "gm";
              mode = [
                "n"
                "x"
              ];
              action = "searchSkipCursor(1)";
              options.desc = "Skip next search cursor";
            }
            {
              key = "gM";
              mode = [
                "n"
                "x"
              ];
              action = "searchSkipCursor(-1)";
              options.desc = "Skip previous search cursor";
            }
            # Add and remove cursors with control + left click
            {
              key = "<M-leftmouse>";
              mode = "n";
              action = "handleMouse()";
              options.desc = "Handle multicursor mouse";
            }
            {
              key = "<M-leftdrag>";
              mode = "n";
              action = "handleMouseDrag()";
              options.desc = "Handle multicursor mouse drag";
            }
            {
              key = "<M-leftrelease>";
              mode = "n";
              action = "handleMouseRelease()";
              options.desc = "Handle multicursor mouse release";
            }
          ]
      );
    };
}
