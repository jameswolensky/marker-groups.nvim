---Test configuration for marker-groups.nvim
---Provides shared configuration and utilities for all tests

local M = {}

---Default test configuration
M.config = {
  -- Test timeouts
  default_timeout = 5000,
  integration_timeout = 10000,
  
  -- Test data directory
  test_data_dir = vim.fn.tempname() .. "_marker_groups_tests",
  
  -- Plugin configuration for tests
  plugin_config = {
    data_dir = nil, -- Will be set to test_data_dir
    log_level = "debug",
    auto_save = false,
    backup_count = 2,
    keymaps = { enabled = false },
    debug = true,
  },
  
  -- Cleanup settings
  cleanup_on_exit = true,
  preserve_logs = false,
}

---Initialize test environment
function M.setup()
  -- Set test data directory
  M.config.plugin_config.data_dir = M.config.test_data_dir
  
  -- Ensure clean test environment
  if vim.fn.isdirectory(M.config.test_data_dir) == 1 then
    vim.fn.delete(M.config.test_data_dir, "rf")
  end
  
  vim.fn.mkdir(M.config.test_data_dir, "p")
  
  -- Initialize plugin with test configuration
  local marker_groups = require('marker-groups')
  marker_groups.setup(M.config.plugin_config)
  
  print("Test environment initialized at: " .. M.config.test_data_dir)
end

---Clean up test environment
function M.teardown()
  if M.config.cleanup_on_exit and vim.fn.isdirectory(M.config.test_data_dir) == 1 then
    vim.fn.delete(M.config.test_data_dir, "rf")
    print("Test environment cleaned up")
  end
end

---Create a test marker with default values
---@param overrides table? Values to override defaults
---@return table marker Test marker object
function M.create_test_marker(overrides)
  local defaults = {
    buffer_path = vim.fn.expand('%:p'),
    start_line = 1,
    end_line = 1,
    annotation = 'Test marker',
    timestamp = os.time(),
  }
  
  return vim.tbl_extend('force', defaults, overrides or {})
end

---Create a temporary file for testing
---@param content string? File content
---@param extension string? File extension (default: 'lua')
---@return string filepath Path to created file
function M.create_temp_file(content, extension)
  extension = extension or 'lua'
  content = content or 'local M = {}\nreturn M'
  
  local filepath = M.config.test_data_dir .. '/test_file_' .. os.time() .. '.' .. extension
  
  local file = io.open(filepath, 'w')
  if file then
    file:write(content)
    file:close()
  end
  
  return filepath
end

---Wait for condition with timeout
---@param condition function Function that returns true when condition is met
---@param timeout number? Timeout in milliseconds (default: 1000)
---@param interval number? Check interval in milliseconds (default: 10)
---@return boolean success True if condition was met within timeout
function M.wait_for(condition, timeout, interval)
  timeout = timeout or 1000
  interval = interval or 10
  
  local start_time = vim.loop.hrtime()
  local timeout_ns = timeout * 1000000 -- Convert to nanoseconds
  
  while (vim.loop.hrtime() - start_time) < timeout_ns do
    if condition() then
      return true
    end
    vim.wait(interval)
  end
  
  return false
end

---Assert that function throws an error
---@param func function Function to test
---@param expected_error string? Expected error message pattern
function M.assert_error(func, expected_error)
  local success, err = pcall(func)
  
  assert(not success, "Expected function to throw an error, but it succeeded")
  
  if expected_error then
    assert(type(err) == "string" and string.match(err, expected_error), 
           "Error message '" .. tostring(err) .. "' does not match expected pattern '" .. expected_error .. "'")
  end
end

---Get test statistics
---@return table stats Test execution statistics
function M.get_stats()
  return {
    test_data_dir = M.config.test_data_dir,
    temp_files_created = #vim.fn.glob(M.config.test_data_dir .. '/test_file_*', false, true),
    memory_usage = collectgarbage("count"),
    timestamp = os.date("%Y-%m-%d %H:%M:%S"),
  }
end

return M