-- `ui2` is the upstream redesign of the cmdline and message layer, replacing
-- noice.nvim. Notifications stay with snacks.notifier.
--
-- `enable()` is a no-op while no UI is attached, which is the case at config
-- time for `--embed` clients such as neovide. It attaches by namespace, so one
-- call also covers a later `:detach!` and `:connect`.

vim.api.nvim_create_autocmd("UIEnter", {
  group = vim.api.nvim_create_augroup("ui2", { clear = true }),
  once = true,
  desc = "Enable the builtin cmdline and message UI",
  callback = function()
    require("vim._core.ui2").enable()
  end,
})
