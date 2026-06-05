{
  flake.modules.nixvim.default =
    {
      lib',
      lib,
      config,
      ...
    }:
    {
      keymaps = lib.mkIf config.plugins.snacks.enable (
        lib'.mkVimKeymaps
          {
            prefix = "Snacks.";
            raw = true;
          }
          [
            # https://github.com/folke/snacks.nvim#-usage
            # Top Pickers & Explorer
            {
              key = "<leader><space>";
              action = "picker.smart()";
              options.desc = "Smart Find Files";
            }
            {
              key = "<leader>,";
              action = "picker.buffers()";
              options.desc = "Buffers";
            }
            {
              key = "<leader>/";
              action = "picker.grep()";
              options.desc = "Grep";
            }
            {
              key = "<leader>:";
              action = "picker.command_history()";
              options.desc = "Command History";
            }
            {
              key = "<leader>mm";
              action = "picker.notifications()";
              options.desc = "Notification History";
            }
            {
              key = "<leader>e";
              action = "explorer()";
              options.desc = "File Explorer";
            }
            # find
            {
              key = "<leader>fb";
              action = "picker.buffers()";
              options.desc = "Buffers";
            }
            {
              key = "<leader>fc";
              action = "picker.files({ cwd = vim.fn.stdpath(\"config\") })";
              options.desc = "Find Config File";
            }
            {
              key = "<leader>ff";
              action = "picker.files()";
              options.desc = "Find Files";
            }
            {
              key = "<leader>fg";
              action = "picker.git_files()";
              options.desc = "Find Git Files";
            }
            {
              key = "<leader>fp";
              action = ''picker.projects({ dev = { "~/dev", "~/Developer" }, patterns = { ".git", "flake.nix" } })'';
              options.desc = "Projects";
            }
            {
              key = "<leader>fr";
              action = "picker.recent()";
              options.desc = "Recent";
            }
            # git
            {
              key = "<leader>gb";
              action = "picker.git_branches()";
              options.desc = "Git Branches";
            }
            {
              key = "<leader>gl";
              action = "picker.git_log()";
              options.desc = "Git Log";
            }
            {
              key = "<leader>gL";
              action = "picker.git_log_line()";
              options.desc = "Git Log Line";
            }
            {
              key = "<leader>gs";
              action = "picker.git_status()";
              options.desc = "Git Status";
            }
            {
              key = "<leader>gS";
              action = "picker.git_stash()";
              options.desc = "Git Stash";
            }
            {
              key = "<leader>gd";
              action = "picker.git_diff()";
              options.desc = "Git Diff (Hunks)";
            }
            {
              key = "<leader>gf";
              action = "picker.git_log_file()";
              options.desc = "Git Log File";
            }
            # GitHub
            {
              key = "<leader>gi";
              action = "picker.gh_issue()";
              options.desc = "GitHub Issues (open)";
            }
            {
              key = "<leader>gI";
              action = ''picker.gh_issue({ state = "all" })'';
              options.desc = "GitHub Issues (all)";
            }
            {
              key = "<leader>gp";
              action = "picker.gh_pr()";
              options.desc = "GitHub Pull Requests (open)";
            }
            {
              key = "<leader>gP";
              action = ''picker.gh_pr({ state = "all" })'';
              options.desc = "GitHub Pull Requests (all)";
            }
            # Grep
            {
              key = "<leader>sB";
              action = "picker.grep_buffers()";
              options.desc = "Grep Open Buffers";
            }
            {
              key = "<leader>sg";
              action = "picker.grep()";
              options.desc = "Grep";
            }
            {
              key = "<leader>sw";
              action = "picker.grep_word()";
              options.desc = "Visual selection or word";
              mode = [
                "n"
                "x"
              ];
            }
            # search
            {
              key = "<leader>s\"";
              action = "picker.registers()";
              options.desc = "Registers";
            }
            {
              key = "<leader>s/";
              action = "picker.search_history()";
              options.desc = "Search History";
            }
            {
              key = "<leader>sa";
              action = "picker.autocmds()";
              options.desc = "Autocmds";
            }
            {
              key = "<leader>sb";
              action = "picker.lines()";
              options.desc = "Buffer Lines";
            }
            {
              key = "<leader>sc";
              action = "picker.command_history()";
              options.desc = "Command History";
            }
            {
              key = "<leader>sC";
              action = "picker.commands()";
              options.desc = "Commands";
            }
            {
              key = "<leader>sd";
              action = "picker.diagnostics()";
              options.desc = "Diagnostics";
            }
            {
              key = "<leader>sD";
              action = "picker.diagnostics_buffer()";
              options.desc = "Buffer Diagnostics";
            }
            {
              key = "<leader>sh";
              action = "picker.help()";
              options.desc = "Help Pages";
            }
            {
              key = "<leader>sH";
              action = "picker.highlights()";
              options.desc = "Highlights";
            }
            {
              key = "<leader>si";
              action = "picker.icons()";
              options.desc = "Icons";
            }
            {
              key = "<leader>sj";
              action = "picker.jumps()";
              options.desc = "Jumps";
            }
            {
              key = "<leader>sk";
              action = "picker.keymaps()";
              options.desc = "Keymaps";
            }
            {
              key = "<leader>sl";
              action = "picker.loclist()";
              options.desc = "Location List";
            }
            {
              key = "<leader>sm";
              action = "picker.marks()";
              options.desc = "Marks";
            }
            {
              key = "<leader>sM";
              action = "picker.man()";
              options.desc = "Man Pages";
            }
            {
              key = "<leader>sp";
              action = "picker.lazy()";
              options.desc = "Search for Plugin Spec";
            }
            {
              key = "<leader>sq";
              action = "picker.qflist()";
              options.desc = "Quickfix List";
            }
            {
              key = "<leader>sR";
              action = "picker.resume()";
              options.desc = "Resume";
            }
            {
              key = "<leader>su";
              action = "picker.undo()";
              options.desc = "Undo History";
            }
            {
              key = "<leader>uC";
              action = "picker.colorschemes()";
              options.desc = "Colorschemes";
            }
            # LSP
            {
              key = "gd";
              action = "picker.lsp_definitions()";
              options.desc = "Goto Definition";
            }
            {
              key = "gD";
              action = "picker.lsp_declarations()";
              options.desc = "Goto Declaration";
            }
            {
              key = "gr";
              action = "picker.lsp_references()";
              options.nowait = true;
              options.desc = "References";
            }
            {
              key = "gI";
              action = "picker.lsp_implementations()";
              options.desc = "Goto Implementation";
            }
            {
              key = "gy";
              action = "picker.lsp_type_definitions()";
              options.desc = "Goto T[y]pe Definition";
            }
            {
              key = "gai";
              action = "picker.lsp_incoming_calls()";
              options.desc = "C[a]lls Incoming";
            }
            {
              key = "gao";
              action = "picker.lsp_outgoing_calls()";
              options.desc = "C[a]lls Outgoing";
            }
            {
              key = "<leader>ss";
              action = "picker.lsp_symbols()";
              options.desc = "LSP Symbols";
            }
            {
              key = "<leader>sS";
              action = "picker.lsp_workspace_symbols()";
              options.desc = "LSP Workspace Symbols";
            }
            # Other
            {
              key = "<leader>z";
              action = "zen()";
              options.desc = "Toggle Zen Mode";
            }
            {
              key = "<leader>Z";
              action = "zen.zoom()";
              options.desc = "Toggle Zoom";
            }
            {
              key = "<leader>.";
              action = "scratch()";
              options.desc = "Toggle Scratch Buffer";
            }
            {
              key = "<leader>bs";
              action = "scratch.select()";
              options.desc = "Select Scratch Buffer";
            }
            {
              key = "<leader>mh";
              action = "notifier.show_history()";
              options.desc = "Notification History";
            }
            {
              key = "<leader>bd";
              action = "bufdelete()";
              options.desc = "Delete Buffer";
            }
            {
              key = "<leader>cR";
              action = "rename.rename_file()";
              options.desc = "Rename File";
            }
            {
              key = "<leader>gB";
              action = "gitbrowse()";
              options.desc = "Git Browse";
              mode = [
                "n"
                "v"
              ];
            }
            {
              key = "<leader>gg";
              action = "lazygit()";
              options.desc = "Lazygit";
            }
            {
              key = "<leader>md";
              action = "notifier.hide()";
              options.desc = "Dismiss All Notifications";
            }
            {
              key = "<c-`>";
              action = "terminal()";
              options.desc = "Toggle Terminal";
            }
            {
              key = "<c-/>";
              action = "terminal()";
              options.desc = "Toggle Terminal";
            }
            {
              key = "<c-_>";
              action = "terminal()";
              options.desc = "which_key_ignore";
            }
            {
              key = "]]";
              action = "words.jump(vim.v.count1)";
              options.desc = "Next Reference";
              mode = [
                "n"
                "t"
              ];
            }
            {
              key = "[[";
              action = "words.jump(-vim.v.count1)";
              options.desc = "Prev Reference";
              mode = [
                "n"
                "t"
              ];
            }
          ]
      );
    };
}
