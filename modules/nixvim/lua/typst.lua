-- Typst compile/watch driven by the `typst` CLI (tinymist exposes no `watch`),
-- mirroring the zed tasks. The compiled PDF is viewed inline via the shared
-- PdfPreview command (see pdf-preview.lua).

local watches = {}

local function kill_watch(buf)
  local handle = watches[buf]

  if handle then
    handle:kill(15)
    watches[buf] = nil
  end

  return handle ~= nil
end

local function typst(args, on_exit)
  vim.cmd("silent update")
  local cmd = { "typst" }
  vim.list_extend(cmd, args)
  vim.list_extend(cmd, { "--root", ".", vim.api.nvim_buf_get_name(0) })
  return vim.system(cmd, { text = true }, vim.schedule_wrap(on_exit))
end

local function notify_exit(prefix, obj)
  if obj.code == 0 then
    vim.notify(prefix .. ": done", vim.log.levels.INFO)
  else
    vim.notify(prefix .. ": " .. (obj.stderr ~= "" and obj.stderr or "exited " .. obj.code), vim.log.levels.ERROR)
  end
end

local function typst_compile()
  typst({ "compile" }, function(obj)
    notify_exit("typst compile", obj)
  end)
end

local function typst_watch()
  local buf = vim.api.nvim_get_current_buf()

  if watches[buf] then
    vim.notify("typst watch already running", vim.log.levels.WARN)
    return
  end

  watches[buf] = typst({ "watch" }, function(obj)
    watches[buf] = nil

    -- Report crashes, but stay quiet on a deliberate SIGTERM.
    if obj.signal == 0 and obj.code ~= 0 then
      notify_exit("typst watch", obj)
    end
  end)

  vim.notify("typst watch started", vim.log.levels.INFO)

  vim.api.nvim_create_autocmd("BufUnload", {
    buffer = buf,
    once = true,
    callback = function()
      kill_watch(buf)
    end,
  })
end

local function typst_watch_stop()
  if kill_watch(vim.api.nvim_get_current_buf()) then
    vim.notify("typst watch stopped", vim.log.levels.INFO)
  end
end

local command = vim.api.nvim_create_user_command
command("TypstCompile", typst_compile, { desc = "Compile the Typst document" })
command("TypstWatch", typst_watch, { desc = "Watch and recompile the Typst document" })
command("TypstWatchStop", typst_watch_stop, { desc = "Stop watching the Typst document" })
