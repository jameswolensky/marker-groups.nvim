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

function M.validate_input(input, validation_type)
  if validation_type == "group_name" then
    if not input or type(input) ~= "string" then
      return state.Result.error("Group name must be a string", M.ErrorCodes.INVALID_GROUP_NAME)
    end

    local trimmed = vim.trim(input)
    if trimmed == "" then
      return state.Result.error("Group name cannot be empty", M.ErrorCodes.INVALID_GROUP_NAME)
    end

    local sanitized = trimmed:gsub("[\r\n]", " "):gsub("\t", " "):gsub("[\1-\8\11\12\14-\31\127]", ""):gsub("%s+", " ")

    local limit = require("marker-groups.config").get_internal "max_group_name_chars"
    local char_count = vim.fn.strchars(sanitized)
    if char_count > limit then
      return state.Result.error(
        "Group name cannot exceed " .. tostring(limit) .. " characters",
        M.ErrorCodes.INVALID_GROUP_NAME
      )
    end

    return state.Result.ok(sanitized)
  elseif validation_type == "annotation" then
    if not input or type(input) ~= "string" then
      return state.Result.error("Annotation must be a string", M.ErrorCodes.INVALID_MARKER)
    end

    local trimmed = vim.trim(input)
    if trimmed == "" then
      return state.Result.error("Annotation cannot be empty", M.ErrorCodes.INVALID_MARKER)
    end

    local sanitized = trimmed:gsub("[\1-\8\11\12\14-\31\127]", "")

    local limit = require("marker-groups.config").get_internal "max_annotation_chars"
    local char_count = vim.fn.strchars(sanitized)
    if char_count > limit then
      return state.Result.error(
        "Annotation cannot exceed " .. tostring(limit) .. " characters",
        M.ErrorCodes.INVALID_MARKER
      )
    end

    return state.Result.ok(sanitized)
  elseif validation_type == "file_path" then
    if not input or type(input) ~= "string" then
      return state.Result.error("File path must be a string", M.ErrorCodes.INVALID_BUFFER)
    end

    if input == "" then
      return state.Result.error("Buffer has no file path (save the file first)", M.ErrorCodes.INVALID_BUFFER)
    end

    return state.Result.ok(input)
  end

  return state.Result.error("Unknown validation type: " .. tostring(validation_type), "UNKNOWN_VALIDATION")
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

  vim.notify(
    string.format("Error in %s: %s (Code: %s)", operation, result.error or "Unknown", result.code or "UNKNOWN"),
    vim.log.levels.DEBUG
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
