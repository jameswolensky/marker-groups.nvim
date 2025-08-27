local M = {}
local config = require "marker-groups.config"
local logger = require "marker-groups.utils.logger"

function M.prompt_with_limit(opts, max_chars, callback)
  opts = opts or {}
  local limit = max_chars or config.get_internal "max_annotation_chars"
  local backend = (vim and vim.ui and vim.ui.input) and tostring(vim.ui.input) or "<nil>"
  logger.debug(
    string.format(
      "prompt_with_limit: opening input prompt='%s' default_len=%d limit=%d backend=%s",
      tostring(opts.prompt or ""),
      vim.fn.strchars(opts.default or ""),
      limit,
      backend
    )
  )

  -- Defer opening the input to avoid immediate cancellation with some UI overrides
  vim.schedule(function()
    vim.ui.input(opts, function(input)
      if input == nil then
        logger.debug "prompt_with_limit: input=nil (cancelled)"
        callback(nil)
        return
      end

      local trimmed = vim.trim(input)
      local limited = vim.fn.strcharpart(trimmed, 0, limit)
      logger.debug(
        string.format(
          "prompt_with_limit: received input len=%d trimmed_len=%d limited_len=%d",
          vim.fn.strchars(input),
          vim.fn.strchars(trimmed),
          vim.fn.strchars(limited)
        )
      )
      callback(limited)
    end)
  end)
end

function M.prompt_multiline(opts, max_chars, callback)
  opts = opts or {}
  local width = opts.width or 60
  local height = opts.height or 10
  local title = opts.title or "Annotation"
  local default = opts.default or ""

  local uis = vim.api.nvim_list_uis()
  if not uis or #uis == 0 then
    local input_opts = { prompt = title .. ": ", default = default }
    return vim.ui.input(input_opts, function(input)
      if input == nil then
        callback(nil)
        return
      end
      local trimmed = vim.trim(input)
      local limit = max_chars or config.get_internal "max_annotation_chars"
      local limited = vim.fn.strcharpart(trimmed, 0, limit)
      callback(limited)
    end)
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "modifiable", true)

  local lines = {}
  for line in (default .. "\n"):gmatch "(.-)\n" do
    table.insert(lines, line)
  end
  if #lines == 0 then
    lines = { default }
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local columns = vim.o.columns
  local lines = vim.o.lines

  local content_height = math.max(3, height - 1)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = content_height,
    col = math.floor((columns - width) / 2),
    row = math.floor((lines - height) / 2),
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
    zindex = 200,
  })

  vim.api.nvim_win_set_option(win, "wrap", true)

  local footer_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(footer_buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(footer_buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(footer_buf, "modifiable", false)

  local footer_win = vim.api.nvim_open_win(footer_buf, false, {
    relative = "editor",
    width = width,
    height = 1,
    col = math.floor((columns - width) / 2),
    row = math.floor((lines - height) / 2) + content_height,
    style = "minimal",
    border = "rounded",
    title = " Help ",
    title_pos = "center",
    focusable = false,
    zindex = 201,
  })

  pcall(vim.api.nvim_set_hl, 0, "MarkerGroupsInputHint", { default = true, link = "Comment" })

  local function render_footer()
    vim.api.nvim_buf_set_option(footer_buf, "modifiable", true)
    local hint_line = "  Enter = Save    Esc/Q = Cancel"
    vim.api.nvim_buf_set_lines(footer_buf, 0, -1, false, { hint_line })

    pcall(vim.api.nvim_buf_clear_namespace, footer_buf, -1, 0, -1)
    pcall(vim.api.nvim_buf_add_highlight, footer_buf, -1, "MarkerGroupsInputHint", 0, 0, -1)
    vim.api.nvim_buf_set_option(footer_buf, "modifiable", false)
  end
  render_footer()

  vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
    callback = function()
      if footer_win and vim.api.nvim_win_is_valid(footer_win) then
        pcall(vim.api.nvim_win_set_config, footer_win, {
          relative = "editor",
          width = width,
          height = 1,
          col = math.floor((columns - width) / 2),
          row = math.floor((lines - height) / 2) + content_height,
          style = "minimal",
          border = "rounded",
          title = " Help ",
          title_pos = "center",
          focusable = false,
          zindex = 201,
        })
      end
    end,
    desc = "Ensure annotation help footer stays visible",
  })

  local completed = false
  local function finalize(result)
    if completed then
      return
    end
    completed = true
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
    if footer_win and vim.api.nvim_win_is_valid(footer_win) then
      pcall(vim.api.nvim_win_close, footer_win, true)
    end
    callback(result)
  end

  vim.api.nvim_create_autocmd("WinClosed", {
    once = true,
    callback = function()
      finalize(nil)
    end,
    buffer = buf,
    desc = "Close multiline input on window close",
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", {
    noremap = true,
    silent = true,
    callback = function()
      finalize(nil)
    end,
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
    noremap = true,
    silent = true,
    callback = function()
      finalize(nil)
    end,
  })

  local function submit()
    local all = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local joined = table.concat(all, "\n")
    local limit = max_chars or config.get_internal "max_annotation_chars"
    local limited = vim.fn.strcharpart(joined, 0, limit)
    finalize(limited)
  end

  vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", { noremap = true, silent = true, callback = submit })
  vim.api.nvim_buf_set_keymap(buf, "i", "<C-c>", "", {
    noremap = true,
    silent = true,
    callback = function()
      finalize(nil)
    end,
  })

  vim.schedule(function()
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_set_current_win, win)
      pcall(vim.cmd, "startinsert")
    end
  end)
end

return M
