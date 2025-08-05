---@class MarkerGroupsErrorHandling
---Comprehensive error handling and recovery utilities for marker groups
local M = {}

local feedback = require("marker-groups.feedback")
local state = require("marker-groups.state")

---Error categories for better classification
M.ErrorCategory = {
  VALIDATION = "validation",
  STATE = "state", 
  PERSISTENCE = "persistence",
  UI = "ui",
  INTEGRATION = "integration"
}

---Common error codes used throughout the plugin
M.ErrorCodes = {
  -- Validation errors
  INVALID_GROUP_NAME = "INVALID_GROUP_NAME",
  INVALID_MARKER = "INVALID_MARKER", 
  INVALID_BUFFER = "INVALID_BUFFER",
  INVALID_LINE_RANGE = "INVALID_LINE_RANGE",
  
  -- State errors
  GROUP_NOT_FOUND = "GROUP_NOT_FOUND",
  GROUP_EXISTS = "GROUP_EXISTS",
  MARKER_NOT_FOUND = "MARKER_NOT_FOUND",
  STATE_NOT_INITIALIZED = "STATE_NOT_INITIALIZED",
  
  -- Operational errors
  CANNOT_DELETE_DEFAULT = "CANNOT_DELETE_DEFAULT",
  CANNOT_RENAME_DEFAULT = "CANNOT_RENAME_DEFAULT",
  OPERATION_CANCELLED = "OPERATION_CANCELLED",
  
  -- Integration errors
  TELESCOPE_NOT_AVAILABLE = "TELESCOPE_NOT_AVAILABLE",
  PERSISTENCE_FAILED = "PERSISTENCE_FAILED"
}

---Safe execution wrapper that handles errors gracefully
---@param operation string Operation name for error reporting
---@param func function Function to execute safely
---@param fallback? function Optional fallback function if main function fails
---@return table Result object
function M.safe_execute(operation, func, fallback)
  local ok, result = pcall(func)
  
  if not ok then
    -- Unexpected error (not a Result object)
    local error_msg = tostring(result)
    feedback.debug_error(operation, error_msg, {
      stack_trace = debug.traceback(),
      operation = operation
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
  
  -- If result is not a Result object, wrap it
  if type(result) ~= "table" or result.success == nil then
    return state.Result.ok(result)
  end
  
  return result
end

---Validate and sanitize user input
---@param input any User input to validate
---@param validation_type string Type of validation ("group_name", "annotation", "file_path")
---@return table Result object with validated value
function M.validate_input(input, validation_type)
  if validation_type == "group_name" then
    if not input or type(input) ~= "string" then
      return state.Result.error("Group name must be a string", M.ErrorCodes.INVALID_GROUP_NAME)
    end
    
    local trimmed = vim.trim(input)
    if trimmed == "" then
      return state.Result.error("Group name cannot be empty", M.ErrorCodes.INVALID_GROUP_NAME) 
    end
    
    if #trimmed > 50 then
      return state.Result.error("Group name cannot exceed 50 characters", M.ErrorCodes.INVALID_GROUP_NAME)
    end
    
    if not trimmed:match("^[%w%s_-]+$") then
      return state.Result.error("Group name can only contain letters, numbers, spaces, underscores, and hyphens", M.ErrorCodes.INVALID_GROUP_NAME)
    end
    
    return state.Result.ok(trimmed)
    
  elseif validation_type == "annotation" then
    if not input or type(input) ~= "string" then
      return state.Result.error("Annotation must be a string", M.ErrorCodes.INVALID_MARKER)
    end
    
    local trimmed = vim.trim(input)
    if trimmed == "" then
      return state.Result.error("Annotation cannot be empty", M.ErrorCodes.INVALID_MARKER)
    end
    
    if #trimmed > 500 then
      return state.Result.error("Annotation cannot exceed 500 characters", M.ErrorCodes.INVALID_MARKER)
    end
    
    return state.Result.ok(trimmed)
    
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

---Attempt to recover from common error conditions
---@param error_code string Error code to attempt recovery for
---@param context? table Additional context for recovery
---@return table Result object indicating if recovery was successful
function M.attempt_recovery(error_code, context)
  context = context or {}
  
  if error_code == M.ErrorCodes.STATE_NOT_INITIALIZED then
    -- Try to reinitialize state
    local config = require("marker-groups.config")
    local init_result = M.safe_execute("State Recovery", function()
      return state.initialize(config.get_all())
    end)
    
    if init_result.success then
      feedback.success("Recovery", "State reinitialized successfully")
      return state.Result.ok("State recovered")
    else
      feedback.error("Recovery", "Failed to reinitialize state")
      return state.Result.error("State recovery failed", "RECOVERY_FAILED")
    end
    
  elseif error_code == M.ErrorCodes.PERSISTENCE_FAILED then
    -- Try to create backup and continue without persistence
    feedback.warning("Recovery", "Persistence failed, continuing without auto-save")
    return state.Result.ok("Continuing without persistence")
    
  elseif error_code == M.ErrorCodes.TELESCOPE_NOT_AVAILABLE then
    -- Fall back to vim.ui.select
    feedback.warning("Recovery", "Telescope not available, using native UI")
    return state.Result.ok("Using fallback UI")
  end
  
  -- No recovery available for this error code
  return state.Result.error("No recovery available for: " .. error_code, "NO_RECOVERY")
end

---Create a user-friendly error message from a Result object
---@param result table Result object with error information
---@return string User-friendly error message
function M.format_user_error(result)
  if result.success then
    return "Operation completed successfully"
  end
  
  local base_msg = result.error or "Unknown error occurred"
  
  -- Add helpful hints based on error code
  if result.code == M.ErrorCodes.INVALID_GROUP_NAME then
    base_msg = base_msg .. "\nHint: Group names should contain only letters, numbers, spaces, underscores, and hyphens"
  elseif result.code == M.ErrorCodes.GROUP_NOT_FOUND then
    base_msg = base_msg .. "\nHint: Use :MarkerGroupsList to see available groups"
  elseif result.code == M.ErrorCodes.INVALID_BUFFER then
    base_msg = base_msg .. "\nHint: Save the file first to create markers"
  elseif result.code == M.ErrorCodes.STATE_NOT_INITIALIZED then
    base_msg = base_msg .. "\nHint: Try reloading the plugin with :MarkerGroupsReload"
  end
  
  return base_msg
end

---Log error with context for debugging
---@param operation string Operation that failed
---@param result table Result object
---@param context? table Additional context
function M.log_error(operation, result, context)
  local log_data = {
    operation = operation,
    error = result.error,
    code = result.code,
    timestamp = os.time(),
    context = context
  }
  
  -- Use vim's built-in logging if available
  vim.notify(
    string.format("Error in %s: %s (Code: %s)", 
      operation, 
      result.error or "Unknown", 
      result.code or "UNKNOWN"
    ),
    vim.log.levels.DEBUG
  )
end

---Wrap a function to automatically handle Results and provide user feedback
---@param operation string Operation name
---@param func function Function to wrap
---@param options? table Options { show_success?, recovery?, fallback? }
---@return function Wrapped function
function M.wrap_with_feedback(operation, func, options)
  options = options or {}
  
  return function(...)
    local result = M.safe_execute(operation, function() return func(...) end, options.fallback)
    
    if result.success then
      if options.show_success ~= false then
        feedback.success(operation, result.message)
      end
    else
      -- Log the error
      M.log_error(operation, result)
      
      -- Attempt recovery if specified
      if options.recovery and M.ErrorCodes[result.code] then
        local recovery_result = M.attempt_recovery(result.code)
        if recovery_result.success then
          -- Retry the operation after recovery
          local retry_result = M.safe_execute(operation .. " (Retry)", function() return func(...) end)
          if retry_result.success then
            feedback.success(operation, "Operation succeeded after recovery")
            return retry_result
          end
        end
      end
      
      -- Show user-friendly error
      feedback.error(operation, M.format_user_error(result), result.code)
    end
    
    return result
  end
end

return M