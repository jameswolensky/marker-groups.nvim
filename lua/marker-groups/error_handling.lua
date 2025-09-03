local M = {}

local feedback = require "marker-groups.feedback"
local state = require "marker-groups.state"

M.ErrorCategory = {
  VALIDATION = "validation",
  STATE = "state",
  PERSISTENCE = "persistence",
  UI = "ui",
  INTEGRATION = "integration",
}

M.ErrorCodes = {
  INVALID_GROUP_NAME = "INVALID_GROUP_NAME",
  INVALID_MARKER = "INVALID_MARKER",
  INVALID_BUFFER = "INVALID_BUFFER",
  INVALID_LINE_RANGE = "INVALID_LINE_RANGE",

  GROUP_NOT_FOUND = "GROUP_NOT_FOUND",
  GROUP_EXISTS = "GROUP_EXISTS",
  MARKER_NOT_FOUND = "MARKER_NOT_FOUND",
  STATE_NOT_INITIALIZED = "STATE_NOT_INITIALIZED",

  CANNOT_DELETE_DEFAULT = "CANNOT_DELETE_DEFAULT",
  CANNOT_RENAME_DEFAULT = "CANNOT_RENAME_DEFAULT",
  OPERATION_CANCELLED = "OPERATION_CANCELLED",

  PERSISTENCE_FAILED = "PERSISTENCE_FAILED",
}

function M.safe_execute(operation, func, fallback)
  local ok, result = pcall(func)

  if not ok then
    local error_msg = tostring(result)
    feedback.debug_error(operation, error_msg, {
      stack_trace = debug.traceback(),
      operation = operation,
    })

    if fallback then
      local fallback_ok, fallback_result = pcall(fallback)
      if fallback_ok and fallback_result then
        feedback.warning(operation, "Main operation failed, using fallback")
        return fallback_result
      end
    end

    return state.Result.error("Unexpected error: " .. error_msg, "UNEXPECTED_ERROR")
  end

  if type(result) ~= "table" or result.success == nil then
    return state.Result.ok(result)
  end

  return result
end

local function join_non_empty(parts, sep)
  local out = {}
  for _, p in ipairs(parts) do
    if p and p ~= "" then
      table.insert(out, p)
    end
  end
  return table.concat(out, sep or " ")
end

function M.validate_input(input, field)
  if not input or input == "" then
    return { success = false, error = field .. " cannot be empty", code = "EMPTY_INPUT" }
  end

  if type(input) ~= "string" then
    return { success = false, error = field .. " must be a string", code = "INVALID_TYPE" }
  end

  local value = vim.trim(input)
  if value == "" then
    return { success = false, error = field .. " cannot be empty", code = "EMPTY_INPUT" }
  end

  if field == "annotation" then
    if value:find "\n" or value:find "\r" then
      return { success = false, error = "Annotation cannot contain line breaks", code = "INVALID_ANNOTATION" }
    end
    local cleaned = value:gsub("%c", "")
    local limit = 100
    local len = vim.fn.strchars(cleaned)
    if len > limit then
      return { success = false, error = "Annotation cannot exceed 100 characters", code = "INVALID_ANNOTATION" }
    end
    return { success = true, value = cleaned }
  elseif field == "group_name" then
    local sanitized = value:gsub("[\r\n\t]", " ")
    sanitized = sanitized:gsub("%c", "")
    sanitized = sanitized:gsub("%s+", " ")
    sanitized = vim.trim(sanitized)
    if sanitized == "" then
      return { success = false, error = "Group name cannot be empty", code = "EMPTY_INPUT" }
    end
    local limit = 100
    local len = vim.fn.strchars(sanitized)
    if len > limit then
      return { success = false, error = "Group name exceeds maximum length", code = "INVALID_GROUP_NAME" }
    end
    return { success = true, value = sanitized }
  end

  return { success = true, value = value }
end

function M.handle_error(context)
  local level = context and context.level or vim.log.levels.ERROR
  local title = context and context.title or "Error"
  local message = join_non_empty({ context and context.message or "", context and context.details or "" }, ": ")

  require("marker-groups.feedback").notify(message, level, { title = title, timeout = 5000 })

  return { success = false, error = message, code = context and context.code or "UNKNOWN" }
end

function M.attempt_recovery(error_code, context)
  context = context or {}

  if error_code == M.ErrorCodes.STATE_NOT_INITIALIZED then
    local config = require "marker-groups.config"
    local init_result = M.safe_execute("State Recovery", function()
      return state.initialize(config.get_all())
    end)

    if init_result.success then
      feedback.success("Recovery", "State reinitialized successfully")
      return state.Result.ok "State recovered"
    else
      feedback.error("Recovery", "Failed to reinitialize state")
      return state.Result.error("State recovery failed", "RECOVERY_FAILED")
    end
  elseif error_code == M.ErrorCodes.PERSISTENCE_FAILED then
    feedback.warning("Recovery", "Persistence failed, continuing without auto-save")
    return state.Result.ok "Continuing without persistence"
  end

  return state.Result.error("No recovery available for: " .. error_code, "NO_RECOVERY")
end

function M.format_user_error(result)
  if result.success then
    return "Operation completed successfully"
  end

  local base_msg = result.error or "Unknown error occurred"

  if result.code == M.ErrorCodes.INVALID_GROUP_NAME then
    base_msg = base_msg
      .. "\nHint: Group names can include most characters (including Unicode and emojis), but must be a single line, non-empty, and 100 characters or fewer."
  elseif result.code == M.ErrorCodes.GROUP_NOT_FOUND then
    base_msg = base_msg .. "\nHint: Use :MarkerGroupsList to see available groups"
  elseif result.code == M.ErrorCodes.INVALID_BUFFER then
    base_msg = base_msg .. "\nHint: Save the file first to create markers"
  elseif result.code == M.ErrorCodes.STATE_NOT_INITIALIZED then
    base_msg = base_msg
  end

  return base_msg
end

function M.is_valid_result(result)
  if type(result) ~= "table" then
    return false
  end

  if type(result.success) ~= "boolean" then
    return false
  end

  return true
end

function M.log_error(operation, result, context)
  local log_data = {
    operation = operation,
    error = result.error,
    code = result.code,
    timestamp = os.time(),
    context = context,
  }

  require("marker-groups.feedback").notify(
    string.format("Error in %s: %s (Code: %s)", operation, result.error or "Unknown", result.code or "UNKNOWN"),
    vim.log.levels.DEBUG,
    {}
  )
end

function M.wrap_with_feedback(operation, func, options)
  options = options or {}

  return function(...)
    local args = { ... }
    local result = M.safe_execute(operation, function()
      return func(unpack(args))
    end, options.fallback)

    if result.success then
      if options.show_success ~= false then
        feedback.success(operation, result.message)
      end
    else
      M.log_error(operation, result)

      if options.recovery and M.ErrorCodes[result.code] then
        local recovery_result = M.attempt_recovery(result.code)
        if recovery_result.success then
          local retry_result = M.safe_execute(operation .. " (Retry)", function()
            return func(unpack(args))
          end)
          if retry_result.success then
            feedback.success(operation, "Operation succeeded after recovery")
            return retry_result
          end
        end
      end

      feedback.error(operation, M.format_user_error(result), result.code)
    end

    return result
  end
end

return M
