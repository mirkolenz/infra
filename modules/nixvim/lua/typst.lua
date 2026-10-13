-- Typst compile/watch driven by the `typst` CLI (tinymist exposes no `watch`),
-- mirroring the zed tasks. The compiled PDF is viewed inline via the shared
-- PdfPreview command (see pdf-preview.lua).

local async = vim.async
local system = require("my.system")

-- One watch task per buffer, closing it terminates the process.
local watches = {}

local function kill_watch(buf)
  local task = watches[buf]

  if task then
    task:close()
    watches[buf] = nil
  end

  return task ~= nil
end

-- The project root bounds what the document may import, so packages and shared
-- assets above the document's own directory still resolve.
local function typst_cmd(subcommand)
  vim.cmd("silent update")
  local file = vim.api.nvim_buf_get_name(0)
  local root = vim.fs.root(0, { "typst.toml", ".git" }) or vim.fs.dirname(file)

  return { "typst", subcommand, "--root", root, file }
end

local function notify_exit(prefix, obj)
  if obj.code == 0 then
    vim.notify(prefix .. ": done", vim.log.levels.INFO)
  else
    vim.notify(prefix .. ": " .. (obj.stderr ~= "" and obj.stderr or "exited " .. obj.code), vim.log.levels.ERROR)
  end
end

local function typst_compile()
  local cmd = typst_cmd("compile")

  async.run(function()
    notify_exit("typst compile", system(cmd, { text = true }))
  end)
end

local function typst_watch()
  local buf = vim.api.nvim_get_current_buf()

  if watches[buf] then
    vim.notify("typst watch already running", vim.log.levels.WARN)
    return
  end

  local cmd = typst_cmd("watch")

  watches[buf] = async.run(function()
    -- The watch reports every recompile, so only the latest output is kept for
    -- a crash report instead of buffering it all for the life of the process.
    local stderr = ""
    local obj = system(cmd, {
      text = true,
      stdout = false,
      stderr = function(_, data)
        stderr = data or stderr
      end,
    })
    obj.stderr = stderr
    watches[buf] = nil

    -- A closed task never gets here, so only report crashes and stay quiet on
    -- a SIGTERM from elsewhere.
    if obj.signal == 0 and obj.code ~= 0 then
      notify_exit("typst watch", obj)
    end
  end)

  vim.notify("typst watch started", vim.log.levels.INFO)

  vim.api.nvim_create_autocmd("BufUnload", {
    buf = buf,
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
