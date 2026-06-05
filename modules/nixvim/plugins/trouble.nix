{
  flake.modules.nixvim.default =
    {
      lib',
      lib,
      config,
      ...
    }:
    {
      plugins.trouble = {
        enable = true;
      };
      plugins.todo-comments = {
        enable = true;
      };
      keymaps = lib.mkIf config.plugins.trouble.enable (
        lib'.mkVimKeymaps
          {
            prefix = "Trouble ";
            raw = false;
          }
          [
            {
              key = "<leader>xx";
              mode = "n";
              action = "diagnostics toggle";
              options.desc = "Diagnostics (Trouble)";
            }
            {
              key = "<leader>xX";
              mode = "n";
              action = "diagnostics toggle filter.buf=0";
              options.desc = "Buffer Diagnostics (Trouble)";
            }
            {
              key = "<leader>cs";
              mode = "n";
              action = "symbols toggle focus=false";
              options.desc = "Symbols (Trouble)";
            }
            {
              key = "<leader>cl";
              mode = "n";
              action = "lsp toggle focus=false win.position=right";
              options.desc = "LSP definitions/references/... (Trouble)";
            }
            {
              key = "<leader>xL";
              mode = "n";
              action = "loclist toggle";
              options.desc = "Location List (Trouble)";
            }
            {
              key = "<leader>xQ";
              mode = "n";
              action = "qflist toggle";
              options.desc = "Quickfix List (Trouble)";
            }
            {
              key = "<leader>xt";
              mode = "n";
              action = "todo";
              options.desc = "Todo Comments (Trouble)";
            }
            {
              key = "<leader>xT";
              mode = "n";
              action = "todo filter.buf=0";
              options.desc = "Buffer Todo Comments (Trouble)";
            }
          ]
      );
    };
}
