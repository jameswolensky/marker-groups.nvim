---@class TestRunner
---Test runner for marker-groups.nvim using plenary.nvim testing framework.
---Provides comprehensive test execution and reporting capabilities.

local M = {}

-- Check if plenary is available
local has_plenary, plenary = pcall(require, 'plenary')

if not has_plenary then
  error("plenary.nvim is required for running tests. Please install nvim-lua/plenary.nvim")
end

local Path = require('plenary.path')
local Job = require('plenary.job')

---Test configuration
M.config = {
  test_patterns = {
    unit = "tests/unit/*_spec.lua",
    integration = "tests/integration/*_spec.lua",
    all = "tests/**/*_spec.lua"
  },
  timeout = 30000, -- 30 seconds
  verbose = false,
  coverage = false,
}

---Initialize test environment
function M.setup()
  -- Ensure marker-groups is available for testing
  local has_marker_groups, marker_groups = pcall(require, 'marker-groups')
  if not has_marker_groups then
    error("marker-groups plugin not found. Ensure it's properly installed for testing.")
  end
  
  -- Initialize plugin if not already done
  if not marker_groups.is_initialized() then
    marker_groups.setup({
      -- Test-specific configuration
      data_dir = vim.fn.tempname() .. "_marker_groups_test",
      log_level = "debug",
      auto_save = false, -- Disable auto-save during tests
      keymaps = { enabled = false }, -- Disable keymaps during tests
    })
  end
  
  print("Test environment initialized")
end

---Clean up test environment
function M.teardown()
  -- Clean up any test data
  local config = require('marker-groups.config')
  local data_dir = config.get_value("data_dir")
  
  if data_dir and vim.fn.isdirectory(data_dir) == 1 then
    vim.fn.delete(data_dir, "rf")
  end
  
  print("Test environment cleaned up")
end

---Run specific test suite
---@param suite_type string Test suite type: 'unit', 'integration', or 'all'
---@param opts table? Options for test execution
function M.run_suite(suite_type, opts)
  opts = vim.tbl_extend("force", M.config, opts or {})
  
  local pattern = M.config.test_patterns[suite_type]
  if not pattern then
    error("Unknown test suite: " .. suite_type)
  end
  
  print("Running " .. suite_type .. " tests...")
  print("Pattern: " .. pattern)
  
  -- Setup test environment
  M.setup()
  
  -- Run tests using plenary
  local test_harness = require('plenary.test_harness')
  
  local results = test_harness.test_directory(
    vim.fn.expand(pattern),
    {
      timeout = opts.timeout,
      verbose = opts.verbose,
    }
  )
  
  -- Cleanup
  M.teardown()
  
  return results
end

---Run all tests
---@param opts table? Options for test execution
function M.run_all(opts)
  return M.run_suite('all', opts)
end

---Run unit tests only
---@param opts table? Options for test execution
function M.run_unit(opts)
  return M.run_suite('unit', opts)
end

---Run integration tests only
---@param opts table? Options for test execution
function M.run_integration(opts)
  return M.run_suite('integration', opts)
end

---Run a specific test file
---@param test_file string Path to test file
---@param opts table? Options for test execution
function M.run_file(test_file, opts)
  opts = vim.tbl_extend("force", M.config, opts or {})
  
  local file_path = Path:new(test_file)
  if not file_path:exists() then
    error("Test file not found: " .. test_file)
  end
  
  print("Running test file: " .. test_file)
  
  -- Setup test environment
  M.setup()
  
  -- Run specific test file
  local test_harness = require('plenary.test_harness')
  local results = test_harness.test_directory(
    test_file,
    {
      timeout = opts.timeout,
      verbose = opts.verbose,
    }
  )
  
  -- Cleanup
  M.teardown()
  
  return results
end

---Watch tests for changes and re-run
---@param suite_type string Test suite to watch
function M.watch(suite_type)
  suite_type = suite_type or 'all'
  
  print("Watching " .. suite_type .. " tests for changes...")
  print("Press Ctrl+C to stop watching")
  
  -- Simple file watching implementation
  local last_run = os.time()
  
  while true do
    vim.wait(1000) -- Wait 1 second
    
    -- Check if any test files have been modified
    local pattern = M.config.test_patterns[suite_type]
    local files = vim.fn.glob(pattern, false, true)
    
    local should_run = false
    for _, file in ipairs(files) do
      local stat = vim.loop.fs_stat(file)
      if stat and stat.mtime.sec > last_run then
        should_run = true
        break
      end
    end
    
    if should_run then
      print("\nTest files changed, re-running tests...")
      M.run_suite(suite_type, { verbose = true })
      last_run = os.time()
    end
  end
end

---Generate test coverage report (placeholder)
function M.coverage()
  print("Coverage reporting not yet implemented")
  print("Consider using luacov or similar tools for Lua code coverage")
end

---Register test commands for convenient access
function M.register_commands()
  -- Run all tests
  vim.api.nvim_create_user_command("MarkerGroupsTestAll", function()
    M.run_all({ verbose = true })
  end, {
    desc = "Run all marker-groups tests"
  })
  
  -- Run unit tests
  vim.api.nvim_create_user_command("MarkerGroupsTestUnit", function()
    M.run_unit({ verbose = true })
  end, {
    desc = "Run marker-groups unit tests"
  })
  
  -- Run integration tests
  vim.api.nvim_create_user_command("MarkerGroupsTestIntegration", function()
    M.run_integration({ verbose = true })
  end, {
    desc = "Run marker-groups integration tests"
  })
  
  -- Run specific test file
  vim.api.nvim_create_user_command("MarkerGroupsTestFile", function(args)
    local file = args.args
    if file == "" then
      vim.notify("Please specify a test file", vim.log.levels.ERROR)
      return
    end
    M.run_file(file, { verbose = true })
  end, {
    nargs = 1,
    desc = "Run specific test file",
    complete = function()
      return vim.fn.glob("tests/**/*_spec.lua", false, true)
    end
  })
  
  -- Watch tests
  vim.api.nvim_create_user_command("MarkerGroupsTestWatch", function(args)
    local suite = args.args ~= "" and args.args or "all"
    M.watch(suite)
  end, {
    nargs = "?",
    desc = "Watch tests for changes and re-run",
    complete = function()
      return { "all", "unit", "integration" }
    end
  })
end

return M