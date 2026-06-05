{
  flake.modules.nixvim.default =
    { lib, ... }:
    {
      autoGroups = {
        autoformat = { };
        autodir = { };
      };
      autoCmd = [
        {
          callback = lib.nixvim.mkRaw /* lua */ ''
            function(args)
              vim.lsp.buf.format({
                async = false,
                bufnr = args.buf,
                timeout_ms = 1000,
              })
            end
          '';
          event = "BufWritePre";
          pattern = "*";
          group = "autoformat";
          desc = "Format buffer using LSP";
        }
        {
          callback = lib.nixvim.mkRaw /* lua */ ''
            function()
              local args = vim.fn.argv()

              if #args > 0 then
                local arg = args[1]

                if vim.fn.isdirectory(arg) == 1 then
                  -- Argument is a directory, change to it directly
                  vim.api.nvim_set_current_dir(arg)
                  -- vim.notify("Changed directory to: " .. arg, vim.log.levels.INFO)
                elseif vim.fn.filereadable(arg) == 1 then
                  -- Argument is a file, change to its parent directory
                  local dir = vim.fn.fnamemodify(arg, ":p:h")
                  vim.api.nvim_set_current_dir(dir)
                  -- vim.notify("Changed directory to: " .. dir, vim.log.levels.INFO)
                else
                  -- Argument exists but is neither a readable file nor a directory
                  vim.notify("Argument is not a valid file or directory: " .. arg, vim.log.levels.WARN)
                end
              else
                -- No arguments provided, using current directory
                -- vim.notify("No arguments provided, using current directory", vim.log.levels.INFO)
              end
            end
          '';
          event = "VimEnter";
          pattern = "*";
          group = "autodir";
          desc = "Change to directory based on first argument";
        }
      ];
    };
}
