-- Inline multi-page PDF preview. snacks.image draws the page over the kitty
-- graphics protocol, so it works over SSH on Linux without Skim, zathura, or
-- any other GUI viewer.
--
-- snacks renders a specific page natively (a "file.pdf#page=N" source), but it
-- caches converted images by path with no mtime check, so re-rendering the same
-- source serves a stale image. We therefore rasterise each page to a fresh PNG
-- with pdftoppm and attach that: the unique path is what makes both page turns
-- and live rebuilds (`typst watch`) actually redraw.
--
-- In the preview window: ] / [ turn pages (with a count, e.g. 3]), {n}gg jumps
-- to a page, G to the last, q closes. Toggled by the PdfPreview command (bound
-- to <leader>tp) and shared by every PDF-producing filetype.

local previews = {}

local function source_pdf()
  return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":r") .. ".pdf"
end

local function page_count(pdf)
  local info = vim.system({ "pdfinfo", pdf }):wait()
  return tonumber(info.stdout:match("Pages:%s*(%d+)")) or 1
end

-- Rasterise the current page to a new PNG and hand it to snacks.image.
local function render(state)
  if not (vim.api.nvim_win_is_valid(state.win) and vim.api.nvim_buf_is_valid(state.buf)) then
    return
  end

  state.pages = page_count(state.pdf)
  state.page = math.min(math.max(state.page, 1), state.pages)
  state.count = state.count + 1

  local png = ("%s/%d.png"):format(state.dir, state.count)
  local out = vim.system({
    "pdftoppm", "-png", "-singlefile", "-r", "150",
    "-f", tostring(state.page), "-l", tostring(state.page),
    state.pdf, (png:gsub("%.png$", "")),
  }):wait()

  if out.code ~= 0 then
    return
  end

  vim.wo[state.win].winbar = (" %s  page %d of %d"):format(vim.fn.fnamemodify(state.pdf, ":t"), state.page, state.pages)
  require("snacks.image.buf").attach(state.buf, { src = png })
end

local function close(pdf)
  local state = previews[pdf]

  if not state then
    return
  end

  previews[pdf] = nil
  state.timer:stop()
  state.timer:close()
  pcall(vim.fn.delete, state.dir, "rf")

  if vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
end

local function open(pdf)
  if vim.fn.filereadable(pdf) == 0 then
    vim.notify("No PDF yet, compile first: " .. pdf, vim.log.levels.WARN)
    return
  end

  local state = { pdf = pdf, dir = vim.fn.tempname(), page = 1, count = 0 }
  vim.fn.mkdir(state.dir, "p")
  previews[pdf] = state

  local source = vim.api.nvim_get_current_win()
  vim.cmd("vsplit")
  state.win = vim.api.nvim_get_current_win()
  state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(state.win, state.buf)
  vim.bo[state.buf].bufhidden = "wipe"
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
    buffer = state.buf,
    once = true,
    callback = function()
      close(pdf)
    end,
  })

  local seen
  state.timer = assert(vim.uv.new_timer())
  state.timer:start(0, 500, vim.schedule_wrap(function()
    if not vim.api.nvim_win_is_valid(state.win) then
      close(pdf)
      return
    end

    local stat = vim.uv.fs_stat(pdf)
    local mtime = stat and (stat.mtime.sec .. ":" .. stat.mtime.nsec)

    if mtime and mtime ~= seen then
      seen = mtime
      render(state)
    end
  end))
end

vim.api.nvim_create_user_command("PdfPreview", function()
  local pdf = source_pdf()

  if previews[pdf] then
    close(pdf)
  else
    open(pdf)
  end
end, { desc = "Toggle inline PDF preview" })
