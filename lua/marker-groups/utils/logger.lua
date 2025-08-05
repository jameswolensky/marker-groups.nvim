---@class MarkerGroupsLogger
---A comprehensive logging system for marker-groups.nvim with multiple log levels,
---dedicated log buffer, and configurable output options for development and troubleshooting.
local M = {}

local config = require("marker-groups.config")

-- Log levels with priority ordering
M.levels = {
  debug = 1,
  info = 2,
  warn = 3,
  error = 4,
}

-- Internal state
local _log_buffer = nil
local _setup_complete = false

---Initialize the logging system
---@param force boolean? Force re-initialization even if already setup
function M.setup(force)
  if _setup_complete and not force then
    return
  end
  
  -- Create log buffer if it doesn't exist or is invalid
  if not _log_buffer or not vim.api.nvim_buf_is_valid(_log_buffer) then
    _log_buffer = vim.api.nvim_create_buf(false, true)
    
    if _log_buffer then
      vim.api.nvim_buf_set_name(_log_buffer, "marker-groups-log")
      
      -- Set buffer options
      vim.api.nvim_buf_set_option(_log_buffer, "buftype", "nofile")
      vim.api.nvim_buf_set_option(_log_buffer, "filetype", "log")
      vim.api.nvim_buf_set_option(_log_buffer, "swapfile", false)
      vim.api.nvim_buf_set_option(_log_buffer, "bufhidden", "hide")
      vim.api.nvim_buf_set_option(_log_buffer, "buflisted", false)
      
      -- Add initial header
      local header = {
        "Marker Groups Plugin Log",
        "=======================",
        "Log Level: " .. M.get_level(),
        "Started: " .. os.date("%Y-%m-%d %H:%M:%S"),
        ""
      }
      
      vim.api.nvim_buf_set_lines(_log_buffer, 0, -1, false, header)
    end
  end
  
  _setup_complete = true
  M.debug("Logger initialized successfully")
end

---Get current log level from configuration
---@return string level Current log level
function M.get_level()
  return config.get_value("log_level", "info")
end

---Set log level in configuration
---@param level string New log level (debug, info, warn, error)
---@return boolean success True if level was valid and set
function M.set_level(level)
  if not M.levels[level] then
    M.error("Invalid log level: " .. tostring(level))
    return false
  end
  
  -- Update configuration
  local current_config = config.get()
  current_config.log_level = level
  config.update(current_config)
  
  M.info("Log level changed to: " .. level)
  return true
end

---Check if a log level should be output based on current configuration
---@param level string Log level to check
---@return boolean should_log True if this level should be logged
local function should_log(level)
  local current_level = M.get_level()
  return M.levels[level] >= M.levels[current_level]
end

---Format a log message with timestamp and level
---@param level string Log level
---@param message string Log message
---@return string formatted Formatted log message
local function format_message(level, message)
  local timestamp = os.date("%H:%M:%S")
  return string.format("[%s] [%s] %s", timestamp, level:upper(), message)
end

---Core logging function
---@param level string Log level
---@param message string Message to log
---@param notify_user boolean? Whether to also notify user via vim.notify
function M.log(level, message, notify_user)
  -- Ensure logger is setup
  if not _setup_complete then
    M.setup()
  end
  
  -- Check if this level should be logged
  if not should_log(level) then
    return
  end
  
  -- Format the message
  local formatted = format_message(level, message)
  
  -- Add to log buffer if available
  if _log_buffer and vim.api.nvim_buf_is_valid(_log_buffer) then
    local lines = vim.api.nvim_buf_line_count(_log_buffer)
    vim.api.nvim_buf_set_lines(_log_buffer, lines, lines, false, { formatted })
    
    -- Limit buffer size to prevent memory issues (keep last 1000 lines)
    local max_lines = 1000
    if lines > max_lines then
      local header_lines = 5 -- Keep the header
      local excess_lines = lines - max_lines + header_lines
      vim.api.nvim_buf_set_lines(_log_buffer, header_lines, excess_lines, false, {})
    end
  end
  
  -- Notify user if requested or if it's an error/critical message
  local should_notify = notify_user or level == "error" or 
                       (level == "debug" and config.get_value("debug", false))
  
  if should_notify then
    local vim_level = vim.log.levels[level:upper()]
    if vim_level then
      vim.notify(message, vim_level)
    else
      vim.notify(message, vim.log.levels.INFO)
    end
  end
end

---Log debug message
---@param message string Debug message
---@param notify boolean? Whether to notify user
function M.debug(message, notify)
  M.log("debug", message, notify)
end

---Log info message
---@param message string Info message  
---@param notify boolean? Whether to notify user
function M.info(message, notify)
  M.log("info", message, notify)
end

---Log warning message
---@param message string Warning message
---@param notify boolean? Whether to notify user
function M.warn(message, notify)
  M.log("warn", message, notify)
end

---Log error message
---@param message string Error message
---@param notify boolean? Whether to notify user (defaults to true for errors)
function M.error(message, notify)
  M.log("error", message, notify ~= false) -- Default to true for errors
end

---Show the log buffer in a window
---@param opts table? Window options
function M.show(opts)
  opts = opts or {}
  
  -- Ensure logger is setup
  if not _setup_complete then
    M.setup()
  end
  
  if not _log_buffer or not vim.api.nvim_buf_is_valid(_log_buffer) then
    M.error("Log buffer is not available")
    return
  end
  
  -- Check if buffer is already displayed
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == _log_buffer then
      vim.api.nvim_set_current_win(win)
      return win
    end
  end
  
  -- Open in split
  local height = opts.height or 15
  local position = opts.position or "botright"
  
  vim.cmd(position .. " " .. height .. "split")
  vim.api.nvim_win_set_buf(0, _log_buffer)
  
  -- Set window options
  vim.api.nvim_win_set_option(0, "wrap", false)
  vim.api.nvim_win_set_option(0, "number", true)
  vim.api.nvim_win_set_option(0, "relativenumber", false)
  vim.api.nvim_win_set_option(0, "cursorline", true)
  
  -- Scroll to bottom to show latest logs
  local lines = vim.api.nvim_buf_line_count(_log_buffer)
  if lines > 0 then
    vim.api.nvim_win_set_cursor(0, { lines, 0 })
  end
  
  return vim.api.nvim_get_current_win()
end

---Clear the log buffer
function M.clear()
  if not _log_buffer or not vim.api.nvim_buf_is_valid(_log_buffer) then
    return
  end
  
  -- Preserve header and add clear message
  local header = {
    "Marker Groups Plugin Log",
    "=======================", 
    "Log Level: " .. M.get_level(),
    "Cleared: " .. os.date("%Y-%m-%d %H:%M:%S"),
    ""
  }
  
  vim.api.nvim_buf_set_lines(_log_buffer, 0, -1, false, header)
  M.info("Log buffer cleared")
end

---Get current log buffer contents
---@return string[] lines All lines from the log buffer
function M.get_logs()
  if not _log_buffer or not vim.api.nvim_buf_is_valid(_log_buffer) then
    return {}
  end
  
  return vim.api.nvim_buf_get_lines(_log_buffer, 0, -1, false)
end

---Write logs to a file
---@param filepath string Path to write log file
---@return boolean success True if file was written successfully
function M.write_to_file(filepath)
  local logs = M.get_logs()
  if #logs == 0 then
    M.warn("No logs to write")
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

---Get logger status and statistics
---@return table status Logger status information
function M.get_status()
  local status = {
    initialized = _setup_complete,
    buffer_valid = _log_buffer and vim.api.nvim_buf_is_valid(_log_buffer) or false,
    current_level = M.get_level(),
    available_levels = vim.tbl_keys(M.levels),
    log_count = 0,
    buffer_id = _log_buffer
  }
  
  if status.buffer_valid then
    status.log_count = vim.api.nvim_buf_line_count(_log_buffer) - 5 -- Subtract header lines
  end
  
  return status
end

---Register logger commands
function M.register_commands()
  -- Show log buffer
  vim.api.nvim_create_user_command("MarkerGroupsShowLogs", function()
    M.show()
  end, {
    desc = "Show marker-groups log buffer"
  })
  
  -- Clear log buffer
  vim.api.nvim_create_user_command("MarkerGroupsClearLogs", function()
    M.clear()
  end, {
    desc = "Clear marker-groups log buffer"
  })
  
  -- Set log level
  vim.api.nvim_create_user_command("MarkerGroupsLogLevel", function(args)
    local level = args.args
    if level == "" then
      vim.notify("Current log level: " .. M.get_level(), vim.log.levels.INFO)
    else
      if M.set_level(level) then
        vim.notify("Log level set to: " .. level, vim.log.levels.INFO)
      end
    end
  end, {
    nargs = "?",
    desc = "Get or set log level",
    complete = function()
      return vim.tbl_keys(M.levels)
    end
  })
  
  -- Write logs to file
  vim.api.nvim_create_user_command("MarkerGroupsWriteLogs", function(args)
    local filepath = args.args
    if filepath == "" then
      filepath = vim.fn.stdpath("data") .. "/marker-groups-logs-" .. os.date("%Y%m%d-%H%M%S") .. ".log"
    end
    
    if M.write_to_file(filepath) then
      vim.notify("Logs written to: " .. filepath, vim.log.levels.INFO)
    end
  end, {
    nargs = "?",
    desc = "Write logs to file",
    complete = "file"
  })
  
  -- Log status
  vim.api.nvim_create_user_command("MarkerGroupsLogStatus", function()
    local status = M.get_status()
    local lines = {
      "Logger Status:",
      "═════════════",
      "",
      "Initialized: " .. (status.initialized and "✅" or "❌"),
      "Buffer Valid: " .. (status.buffer_valid and "✅" or "❌"),
      "Current Level: " .. status.current_level,
      "Log Count: " .. status.log_count,
      "Buffer ID: " .. (status.buffer_id or "none"),
      "",
      "Available Levels: " .. table.concat(status.available_levels, ", ")
    }
    
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
  end, {
    desc = "Show logger status information"
  })
end

return M