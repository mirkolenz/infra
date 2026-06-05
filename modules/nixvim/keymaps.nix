{
  flake.modules.nixvim.default = {
    keymaps = [
      {
        key = "<C-v>";
        mode = "i";
        action = "<C-r>+";
        options.desc = "Paste from system clipboard in insert mode";
      }
      {
        key = "<C-v>";
        mode = [
          "n"
          "v"
        ];
        action = ''"+p'';
        options.desc = "Paste from system clipboard";
      }
      {
        key = "<Esc>";
        mode = "n";
        action = "<cmd>nohlsearch<CR>";
        options.desc = "Clear search highlights";
      }
      {
        key = "<Esc><Esc>";
        mode = "t";
        action = "<C-\\><C-n>";
        options.desc = "Exit terminal mode";
      }
      {
        key = "<leader>p";
        mode = "x";
        action = ''"_dp'';
        options.desc = "Delete to null register and paste after";
      }
      {
        key = "<leader>P";
        mode = "x";
        action = ''"_dP'';
        options.desc = "Delete to null register and paste before";
      }
      {
        key = "<leader>y";
        mode = [
          "n"
          "v"
        ];
        action = ''"+y'';
        options.desc = "Yank to system clipboard";
      }
      {
        key = "<leader>Y";
        mode = "n";
        action = ''"+Y'';
        options.desc = "Yank to system clipboard (whole line)";
      }
      {
        key = "<leader>d";
        mode = [
          "n"
          "v"
        ];
        action = ''"_d'';
        options.desc = "Delete without yanking";
      }
      {
        key = "<leader>D";
        mode = "n";
        action = ''"_D'';
        options.desc = "Delete without yanking (whole line)";
      }
      {
        key = "<leader>;";
        mode = "n";
        action = ":!";
        options.desc = "Execute shell command";
      }
      {
        key = "<leader>l";
        mode = "n";
        action = ":lua<Space>";
        options.desc = "Enter Lua command mode";
      }
      {
        key = "<leader>:";
        mode = "n";
        action = ":noautocmd<Space>";
        options.desc = "Run without autocommands";
      }
      # Use <C-[hjkl]> to switch between windows
      {
        key = "<C-h>";
        mode = "n";
        action = "<C-w>h";
        options.desc = "Switch to window on the left";
      }
      {
        key = "<C-j>";
        mode = "n";
        action = "<C-w>j";
        options.desc = "Switch to window below";
      }
      {
        key = "<C-k>";
        mode = "n";
        action = "<C-w>k";
        options.desc = "Switch to window above";
      }
      {
        key = "<C-l>";
        mode = "n";
        action = "<C-w>l";
        options.desc = "Switch to window on the right";
      }
      # Use <M-u>[aouAOU] to write Umlauts
      {
        key = "<M-u>a";
        mode = "i";
        action = "ä";
        options.desc = "Write 'ä'";
      }
      {
        key = "<M-u>o";
        mode = "i";
        action = "ö";
        options.desc = "Write 'ö'";
      }
      {
        key = "<M-u>u";
        mode = "i";
        action = "ü";
        options.desc = "Write 'ü'";
      }
      {
        key = "<M-u>A";
        mode = "i";
        action = "Ä";
        options.desc = "Write 'Ä'";
      }
      {
        key = "<M-u>O";
        mode = "i";
        action = "Ö";
        options.desc = "Write 'Ö'";
      }
      {
        key = "<M-u>U";
        mode = "i";
        action = "Ü";
        options.desc = "Write 'Ü'";
      }
      {
        key = "<M-s>";
        mode = "i";
        action = "ß";
        options.desc = "Write 'ß'";
      }
    ];
  };
}
