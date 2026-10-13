-- Inline multi-page PDF preview drawn with `vim.ui.img`, Neovim's builtin image
-- API (Kitty graphics protocol, which also works over SSH). `tdf`, the viewer
-- used everywhere else, is unusable in a :terminal split because Neovim's
-- terminal does not forward the graphics protocol.
--
-- In the preview window: ] / [ turn pages (with a count, e.g. 3]), {n}gg jumps
-- to a page, G to the last, q closes. Toggled by the PdfPreview command (bound
-- to <leader>tp) and shared by every PDF-producing filetype.

local async = vim.async
local system = require("my.system")

local DPI = 150
-- Neovim's API reports no cell size, so assume cells are twice as tall as wide.
local CELL_ASPECT = 2
-- Compilers write the PDF in bursts, so wait for a quiet period before reading it.
local DEBOUNCE_MS = 200

local previews = {}

local function source_pdf()
  return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p:r") .. ".pdf"
end

local function pdf_info(pdf)
  local out = system({ "pdfinfo", pdf }, { text = true })
  local width, height = out.stdout:match("Page size:%s*([%d.]+) x ([%d.]+)")

  return tonumber(out.stdout:match("Pages:%s*(%d+)")) or 1, (tonumber(height) or 842) / (tonumber(width) or 595)
end

local function rasterise(pdf, page)
  local nr = tostring(page)
  local out = system({
    "pdftoppm", "-png", "-singlefile", "-r", tostring(DPI), "-f", nr, "-l", nr, pdf,
  })

  return out.code == 0 and out.stdout or nil
end

local function box(state)
  local win = vim.fn.getwininfo(state.win)[1]
  local avail = win.width - win.textoff
  local height = math.min(win.height, math.floor(avail * state.aspect / CELL_ASPECT))
  local width = math.floor(height * CELL_ASPECT / state.aspect)

  return {
    row = win.winrow + win.winbar,
    col = win.wincol + win.textoff + math.floor((avail - width) / 2),
    width = width,
    height = height,
  }
end

local function visible(state)
  return vim.api.nvim_win_is_valid(state.win)
    and vim.api.nvim_win_get_tabpage(state.win) == vim.api.nvim_get_current_tabpage()
end

local function hide(state)
  if state.img then
    vim.ui.img.del(state.img)
    state.img = nil
  end
end

local function place(state)
  if not (state.png and visible(state)) then
    hide(state)
    return
  end

  local geom = box(state)
  -- nil once something else drops every image, which strands the id.
  local placed = state.img and vim.ui.img.get(state.img)

  if not placed then
    state.img = vim.ui.img.set(state.png, geom)
  elseif not vim.deep_equal(geom, placed) then
    vim.ui.img.set(state.img, geom)
  end
end

-- Only one task renders at a time: a turn requested mid-flight just marks the
-- state pending, so holding ] costs one rasterise rather than one per keypress.
-- `rev` counts the rebuilds, so a rebuild still re-renders the current page
-- while a keypress that resolves to what is already shown does not.
-- A hidden preview renders nothing and catches up once it is back in view.
-- The task is detached, so it outlives the callback that started it.
local function render(state)
  if not visible(state) then
    return
  end

  -- Skip the task for a keypress that resolves to the page already shown.
  if state.info_rev == state.rev then
    state.page = math.min(math.max(state.page, 1), state.pages)

    if state.page .. ":" .. state.rev == state.shown then
      return
    end
  end

  if state.task and not state.task:completed() then
    state.pending = true
    return
  end

  state.task = async.run(function()
    repeat
      state.pending = false

      if not visible(state) then
        return
      end

      if state.info_rev ~= state.rev then
        state.info_rev = state.rev
        state.pages, state.aspect = pdf_info(state.pdf)
      end

      state.page = math.min(math.max(state.page, 1), state.pages)

      local page = state.page
      local key = page .. ":" .. state.rev

      if key ~= state.shown then
        local png = rasterise(state.pdf, page)

        if png and vim.api.nvim_win_is_valid(state.win) then
          state.shown, state.png = key, png
          vim.wo[state.win].winbar = (" %s  page %d of %d"):format(vim.fs.basename(state.pdf), page, state.pages)
          -- New bytes need a new placement.
          hide(state)
          place(state)
        end
      end
    until not state.pending
  end):detach()
end

local function close(pdf)
  local state = previews[pdf]

  if not state then
    return
  end

  previews[pdf] = nil
  state.watcher:close()
  state.debounce:close()

  if state.task then
    state.task:close()
  end

  hide(state)

  if vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
end

local function open(pdf)
  if vim.fn.filereadable(pdf) == 0 then
    vim.notify("No PDF yet, compile first: " .. pdf, vim.log.levels.WARN)
    return
  end

  local state = { pdf = pdf, page = 1, rev = 0 }
  previews[pdf] = state

  local source = vim.api.nvim_get_current_win()
  vim.cmd("vsplit")
  state.win = vim.api.nvim_get_current_win()
  state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(state.win, state.buf)
  vim.bo[state.buf].bufhidden = "wipe"

  -- Every decoration steals cells from the image.
  local wo = vim.wo[state.win]
  wo.cursorline, wo.foldcolumn, wo.list, wo.spell, wo.wrap = false, "0", false, false, false
  wo.number, wo.relativenumber, wo.signcolumn = false, false, "no"
  wo.winpinned = true -- survives `:only`; the q mapping below still targets it

  vim.api.nvim_set_current_win(source)

  local function goto_page(page)
    state.page = page
    render(state)
  end

  local function map(lhs, rhs)
    vim.keymap.set("n", lhs, rhs, { buffer = state.buf, nowait = true })
  end

  map("]", function()
    goto_page(state.page + vim.v.count1)
  end)
  map("[", function()
    goto_page(state.page - vim.v.count1)
  end)
  map("gg", function()
    goto_page(vim.v.count1)
  end)
  map("G", function()
    goto_page(vim.v.count > 0 and vim.v.count or math.huge)
  end)
  map("q", function()
    close(pdf)
  end)

  vim.api.nvim_create_autocmd("BufWipeout", {
    buf = state.buf,
    once = true,
    callback = function()
      close(pdf)
    end,
  })

  -- Compilers often replace the PDF by renaming a temporary file over it, which
  -- a watch on the file itself would lose, so watch its directory instead.
  -- The filename check runs in the fast callback, so unrelated writes such as
  -- aux and log files never reach the main loop. Restarting the timer debounces.
  local name = vim.fs.basename(pdf)
  state.debounce = assert(vim.uv.new_timer())
  state.watcher = assert(vim.uv.new_fs_event())
  state.watcher:start(vim.fs.dirname(pdf), {}, function(err, filename)
    if err or filename ~= name then
      return
    end

    state.debounce:start(DEBOUNCE_MS, 0, vim.schedule_wrap(function()
      state.rev = state.rev + 1
      render(state)
    end))
  end)

  render(state)
end

-- Placements are absolute screen rectangles, so any reflow invalidates them.
-- Visibility only changes with the tab, which is when a hidden preview catches up.
vim.api.nvim_create_autocmd({ "VimResized", "WinResized", "WinNew", "WinClosed", "TabEnter" }, {
  group = vim.api.nvim_create_augroup("pdf-preview", { clear = true }),
  callback = vim.schedule_wrap(function(ev)
    for _, state in pairs(previews) do
      place(state)

      if ev.event == "TabEnter" then
        render(state)
      end
    end
  end),
})

vim.api.nvim_create_user_command("PdfPreview", function()
  local pdf = source_pdf()

  if previews[pdf] then
    close(pdf)
  else
    open(pdf)
  end
end, { desc = "Toggle inline PDF preview" })
