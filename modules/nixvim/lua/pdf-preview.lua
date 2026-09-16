-- Inline multi-page PDF preview drawn with `vim.ui.img`, Neovim's builtin image
-- API (Kitty graphics protocol, which also works over SSH). `tdf`, the viewer
-- used everywhere else, is unusable in a :terminal split because Neovim's
-- terminal does not forward the graphics protocol.
--
-- In the preview window: ] / [ turn pages (with a count, e.g. 3]), {n}gg jumps
-- to a page, G to the last, q closes. Toggled by the PdfPreview command (bound
-- to <leader>tp) and shared by every PDF-producing filetype.

local DPI = 150
-- Neovim's API reports no cell size, so assume cells are twice as tall as wide.
local CELL_ASPECT = 2

local previews = {}

local function source_pdf()
  return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":r") .. ".pdf"
end

local function pdf_info(pdf, on_done)
  vim.system({ "pdfinfo", pdf }, { text = true }, vim.schedule_wrap(function(out)
    local width, height = out.stdout:match("Page size:%s*([%d.]+) x ([%d.]+)")

    on_done(tonumber(out.stdout:match("Pages:%s*(%d+)")) or 1, (tonumber(height) or 842) / (tonumber(width) or 595))
  end))
end

local function rasterise(pdf, page, on_done)
  local nr = tostring(page)

  vim.system({
    "pdftoppm", "-png", "-singlefile", "-r", tostring(DPI), "-f", nr, "-l", nr, pdf,
  }, vim.schedule_wrap(function(out)
    on_done(out.code == 0 and out.stdout or nil)
  end))
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

-- Only one pdftoppm runs at a time: a turn requested mid-flight just marks the
-- state pending, so holding ] costs one rasterise rather than one per keypress.
-- `stamp` is the file revision, so a rebuild still re-renders the current page
-- while a keypress that resolves to what is already shown does not.
local function render(state)
  if not (state.pages and visible(state)) then
    return
  end

  local pages = state.pages

  state.page = math.min(math.max(state.page, 1), pages)

  local page = state.page
  local key = page .. ":" .. tostring(state.stamp)

  if key == state.shown then
    return
  end

  if state.busy then
    state.pending = true
    return
  end

  state.busy = true

  rasterise(state.pdf, page, function(png)
    state.busy = false

    if not png then
      state.stamp = nil -- let the next poll retry, the file may still be mid-write
    elseif vim.api.nvim_win_is_valid(state.win) then
      state.shown, state.png = key, png
      vim.wo[state.win].winbar = (" %s  page %d of %d"):format(vim.fn.fnamemodify(state.pdf, ":t"), page, pages)
      -- New bytes need a new placement.
      hide(state)
      place(state)
    end

    if state.pending then
      state.pending = false
      render(state)
    end
  end)
end

local function close(pdf)
  local state = previews[pdf]

  if not state then
    return
  end

  previews[pdf] = nil
  state.timer:stop()
  state.timer:close()
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

  local state = { pdf = pdf, page = 1 }
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

  state.timer = assert(vim.uv.new_timer())
  state.timer:start(0, 500, vim.schedule_wrap(function()
    if not vim.api.nvim_win_is_valid(state.win) then
      close(pdf)
      return
    end

    local stat = vim.uv.fs_stat(pdf)
    local mtime = stat and (stat.mtime.sec .. ":" .. stat.mtime.nsec)

    -- Rasterising for a hidden window is wasted, and leaving `stamp` alone makes
    -- a later tick pick the rebuild up once the tab is back in view.
    if mtime and mtime ~= state.stamp and visible(state) then
      state.stamp = mtime
      pdf_info(pdf, function(pages, aspect)
        state.pages, state.aspect = pages, aspect
        render(state)
      end)
    end
  end))
end

-- Placements are absolute screen rectangles, so any reflow invalidates them.
vim.api.nvim_create_autocmd({ "VimResized", "WinResized", "WinNew", "WinClosed", "TabEnter" }, {
  group = vim.api.nvim_create_augroup("pdf-preview", { clear = true }),
  callback = vim.schedule_wrap(function()
    for _, state in pairs(previews) do
      place(state)
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
