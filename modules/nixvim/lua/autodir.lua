-- Start in the project of the first argument: its git or flake root, else the
-- directory itself or the parent directory of the file.

vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("autodir", { clear = true }),
  once = true,
  desc = "Change to the project of the first argument",
  callback = function()
    local arg = vim.fn.argv(0)

    if arg == "" then
      return
    end

    local path = vim.fs.abspath(arg)
    -- A new file is not on disk yet, so only its directory has to exist.
    local dir = vim.fn.isdirectory(path) == 1 and path or vim.fs.dirname(path)

    if vim.fn.isdirectory(dir) == 0 then
      vim.notify("Argument is not in an existing directory: " .. arg, vim.log.levels.WARN)
      return
    end

    vim.api.nvim_set_current_dir(vim.fs.root(dir, { ".git", "flake.nix" }) or dir)
  end,
})
