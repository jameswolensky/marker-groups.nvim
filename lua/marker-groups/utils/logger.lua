local M = {}

local config = require "marker-groups.config"

M.levels = {
  debug = 1,
  info = 2,
  warn = 3,
  error = 4,
}

local _log_buffer = nil
local _setup_complete = false

function M.setup(force)
  if _setup_complete and not force then
    return
  end

  if not _log_buffer or not vim.api.nvim_buf_is_valid(_log_buffer) then
    _log_buffer = vim.api.nvim_create_buf(false, true)

    if _log_buffer then
      local buffer_name = "marker-groups-log"
      local existing_buf = vim.fn.bufnr(buffer_name)
      if existing_buf ~= -1 and existing_buf ~= _log_buffer then
        buffer_name = buffer_name .. "-" .. _log_buffer
      end

      pcall(vim.api.nvim_buf_set_name, _log_buffer, buffer_name)
      vim.api.nvim_buf_set_option(_log_buffer, "buftype", "nofile")
      vim.api.nvim_buf_set_option(_log_buffer, "filetype", "log")
      vim.api.nvim_buf_set_option(_log_buffer, "swapfile", false)
      vim.api.nvim_buf_set_option(_log_buffer, "bufhidden", "hide")
      vim.api.nvim_buf_set_option(_log_buffer, "buflisted", false)

      local header = {
        "Marker Groups Plugin Log",
        "=======================",
        "Log Level: " .. M.get_level(),
        "Started: " .. os.date "%Y-%m-%d %H:%M:%S",
        "",
      }

      vim.api.nvim_buf_set_lines(_log_buffer, 0, -1, false, header)
    end
  end

  _setup_complete = true
end

function M.get_level()
  return config.get_value("log_level", "info")
end

function M.set_level(level)
  if not M.levels[level] then
    M.error("Invalid log level: " .. tostring(level))
    return false
  end

  local current_config = config.get()
  current_config.log_level = level
  config.update(current_config)

  M.info("Log level changed to: " .. level)
  return true
end

local function should_log(level)
  local current_level = M.get_level()
  return M.levels[level] >= M.levels[current_level]
end

local function format_message(level, message)
  local timestamp = os.date "%H:%M:%S"
  return string.format("[%s] [%s] %s", timestamp, level:upper(), message)
end

function M.log(level, message, notify_user)
  if not _setup_complete then
    M.setup()
  end

  if not should_log(level) then
    return
  end

  local formatted = format_message(level, message)

  if _log_buffer and vim.api.nvim_buf_is_valid(_log_buffer) then
    local lines = vim.api.nvim_buf_line_count(_log_buffer)
    vim.api.nvim_buf_set_lines(_log_buffer, lines, lines, false, { formatted })

    local max_lines = 1000
    if lines > max_lines then
      local header_lines = 5
      local excess_lines = lines - max_lines + header_lines
      vim.api.nvim_buf_set_lines(_log_buffer, header_lines, excess_lines, false, {})
    end
  end

  local should_notify = notify_user or level == "error" or (level == "debug" and config.get_value("debug", false))

  if should_notify then
    local vim_level = vim.log.levels[level:upper()]
    if vim_level then
      vim.notify(message, vim_level)
    else
      vim.notify(message, vim.log.levels.INFO)
    end
  end
end

function M.debug(message, notify)
  M.log("debug", message, notify)
end

function M.info(message, notify)
  M.log("info", message, notify)
end

function M.warn(message, notify)
  M.log("warn", message, notify)
end

function M.error(message, notify)
  M.log("error", message, notify ~= false)
end

function M.show(opts)
  opts = opts or {}

  if not _setup_complete then
    M.setup()
  end

  if not _log_buffer or not vim.api.nvim_buf_is_valid(_log_buffer) then
    M.error "Log buffer is not available"
    return
  end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == _log_buffer then
      vim.api.nvim_set_current_win(win)
      return win
    end
  end

  local height = opts.height or 15
  local position = opts.position or "botright"

  vim.cmd(position .. " " .. height .. "split")
  vim.api.nvim_win_set_buf(0, _log_buffer)

  vim.api.nvim_win_set_option(0, "wrap", false)
  vim.api.nvim_win_set_option(0, "number", true)
  vim.api.nvim_win_set_option(0, "relativenumber", false)
  vim.api.nvim_win_set_option(0, "cursorline", true)

  local lines = vim.api.nvim_buf_line_count(_log_buffer)
  if lines > 0 then
    vim.api.nvim_win_set_cursor(0, { lines, 0 })
  end

  return vim.api.nvim_get_current_win()
end

function M.clear()
  if not _log_buffer or not vim.api.nvim_buf_is_valid(_log_buffer) then
    return
  end

  local header = {
    "Marker Groups Plugin Log",
    "=======================",
    "Log Level: " .. M.get_level(),
    "Cleared: " .. os.date "%Y-%m-%d %H:%M:%S",
    "",
  }

  vim.api.nvim_buf_set_lines(_log_buffer, 0, -1, false, header)
  M.info "Log buffer cleared"
end

function M.get_logs()
  if not _log_buffer or not vim.api.nvim_buf_is_valid(_log_buffer) then
    return {}
  end

  return vim.api.nvim_buf_get_lines(_log_buffer, 0, -1, false)
end

function M.write_to_file(filepath)
  local logs = M.get_logs()
  if #logs == 0 then
    M.warn "No logs to write"
    return false
  end

  local file = io.open(filepath, "w")
  if not file then
    M.error("Failed to open file for writing: " .. filepath)
    return false
  end

  for _, line in ipairs(logs) do
    file:write(line .. "\n")
  end

  file:close()
  M.info("Logs written to: " .. filepath)
  return true
end

function M.get_status()
  local status = {
    initialized = _setup_complete,
    buffer_valid = _log_buffer and vim.api.nvim_buf_is_valid(_log_buffer) or false,
    current_level = M.get_level(),
    available_levels = vim.tbl_keys(M.levels),
    log_count = 0,
    buffer_id = _log_buffer,
  }

  if status.buffer_valid then
    status.log_count = vim.api.nvim_buf_line_count(_log_buffer) - 5
  end

  return status
end

function M.register_commands() end

return M
