---@class MarkerGroupsFeedback
---Centralized user feedback and notification system
local M = {}

local config = require("marker-groups.config")

-- Notification levels
M.levels = {
  ERROR = vim.log.levels.ERROR,
  WARN = vim.log.levels.WARN,
  INFO = vim.log.levels.INFO,
  DEBUG = vim.log.levels.DEBUG,
}

---Show a formatted notification with plugin branding
---@param message string The message to display
---@param level? number Notification level (defaults to INFO)
---@param options? table Additional options { title?, timeout?, replace? }
function M.notify(message, level, options)
  level = level or M.levels.INFO
  options = options or {}
  
  -- Add plugin branding to title
  local title = options.title and ("Marker Groups: " .. options.title) or "Marker Groups"
  
  -- Use vim.notify with enhanced options
  vim.notify(message, level, {
    title = title,
    timeout = options.timeout or (level == M.levels.ERROR and 5000 or 3000),
    replace = options.replace,
    on_open = function(win)
      -- Set window highlights if needed
      if level == M.levels.ERROR then
        vim.api.nvim_win_set_option(win, "winhl", "Normal:ErrorMsg")
      end
    end
  })
end

---Show an error notification
---@param operation string The operation that failed
---@param error_msg string The error message
---@param error_code? string Optional error code
function M.error(operation, error_msg, error_code)
  local formatted_msg = string.format("%s failed: %s", operation, error_msg)
  if error_code then
    formatted_msg = formatted_msg .. string.format(" (Code: %s)", error_code)
  end
  
  M.notify(formatted_msg, M.levels.ERROR, {
    title = "Error",
    timeout = 5000
  })
end

---Show a success notification
---@param operation string The operation that succeeded
---@param details? string Optional success details
function M.success(operation, details)
  local formatted_msg = operation .. " successful"
  if details then
    formatted_msg = formatted_msg .. ": " .. details
  end
  
  M.notify(formatted_msg, M.levels.INFO, {
    title = "Success",
    timeout = 2000
  })
end

---Show a warning notification
---@param operation string The operation context
---@param warning_msg string The warning message
function M.warning(operation, warning_msg)
  local formatted_msg = string.format("%s warning: %s", operation, warning_msg)
  
  M.notify(formatted_msg, M.levels.WARN, {
    title = "Warning",
    timeout = 4000
  })
end

---Handle result object and show appropriate notification
---@param operation string Operation name
---@param result table Result object from operation
---@param success_details? string Optional success details
---@return table The same result object (for chaining)
function M.handle_result(operation, result, success_details)
  if result.success then
    M.success(operation, success_details)
  else
    M.error(operation, result.error or "Unknown error", result.code)
  end
  return result
end

---Show info about a group with formatted display
---@param group_info table Group information
---@param format? string Format type ("short", "long", "table")
function M.show_group_info(group_info, format)
  format = format or "long"
  
  if format == "short" then
    local msg = string.format("%s (%d markers)", group_info.name, group_info.marker_count or 0)
    M.notify(msg, M.levels.INFO, { title = "Group Info" })
  elseif format == "long" then
    local lines = {
      "Group: " .. group_info.name,
      "  Markers: " .. (group_info.marker_count or 0),
      "  Created: " .. (group_info.created_at and os.date("%Y-%m-%d %H:%M", group_info.created_at) or "Unknown"),
      "  Modified: " .. (group_info.modified_at and os.date("%Y-%m-%d %H:%M", group_info.modified_at) or "Unknown")
    }
    if group_info.is_active then
      table.insert(lines, "  Status: ACTIVE")
    end
    M.notify(table.concat(lines, "\n"), M.levels.INFO, { title = "Group Details" })
  end
end

---Show markers in current buffer with formatted display
---@param markers table List of markers
function M.show_buffer_markers(markers)
  if #markers == 0 then
    M.notify("No markers in current buffer", M.levels.INFO, { title = "Buffer Markers" })
    return
  end
  
  local lines = { string.format("Found %d markers:", #markers) }
  for i, marker in ipairs(markers) do
    local line_info = marker.start_line == marker.end_line 
      and string.format("Line %d", marker.start_line)
      or string.format("Lines %d-%d", marker.start_line, marker.end_line)
    
    local annotation = marker.annotation or ""
    if #annotation > 50 then
      annotation = annotation:sub(1, 47) .. "..."
    end
    
    table.insert(lines, string.format("  %d. %s: %s", i, line_info, annotation))
  end
  
  M.notify(table.concat(lines, "\n"), M.levels.INFO, { 
    title = "Buffer Markers",
    timeout = 5000
  })
end

---Show operation progress for long-running operations
---@param operation string Operation name
---@param progress number Progress percentage (0-100)
function M.progress(operation, progress)
  local bar_length = 20
  local filled = math.floor(progress / 100 * bar_length)
  local empty = bar_length - filled
  local bar = string.rep("█", filled) .. string.rep("░", empty)
  
  local msg = string.format("%s: %s %d%%", operation, bar, progress)
  M.notify(msg, M.levels.INFO, {
    title = "Progress",
    timeout = 1000,
    replace = true  -- Replace previous progress notification
  })
end

---Confirm an action with user
---@param message string Confirmation message
---@param callback function Callback function to call if confirmed
---@param options? table Options { yes_text?, no_text?, default? }
function M.confirm(message, callback, options)
  options = options or {}
  local yes_text = options.yes_text or "Yes"
  local no_text = options.no_text or "No"
  
  local choices = { yes_text, no_text }
  
  vim.ui.select(choices, {
    prompt = message,
    format_item = function(item) return item end,
  }, function(choice)
    if choice == yes_text then
      callback(true)
    elseif choice == no_text then
      callback(false)
    else
      -- User cancelled (nil choice)
      callback(nil)
    end
  end)
end

---Show detailed error with debugging information if debug mode is enabled
---@param operation string Operation that failed
---@param error_msg string Error message
---@param debug_info? table Additional debug information
function M.debug_error(operation, error_msg, debug_info)
  M.error(operation, error_msg)
  
  -- Show debug info only if debug mode is enabled
  if config.get_value("debug.enabled", false) and debug_info then
    local debug_lines = { "Debug Information:" }
    for key, value in pairs(debug_info) do
      table.insert(debug_lines, string.format("  %s: %s", key, tostring(value)))
    end
    
    M.notify(table.concat(debug_lines, "\n"), M.levels.DEBUG, {
      title = "Debug Info",
      timeout = 8000
    })
  end
end

return M