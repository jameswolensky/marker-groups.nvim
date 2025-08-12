local M = {}

local has_plenary, plenary = pcall(require, "plenary")

if not has_plenary then
  error "plenary.nvim is required for running tests. Please install nvim-lua/plenary.nvim"
end

local Path = require "plenary.path"
local Job = require "plenary.job"

M.config = {
  test_patterns = {
    unit = "tests/unit/*_spec.lua",
    integration = "tests/integration/*_spec.lua",
    all = "tests/**/*_spec.lua",
  },
  timeout = 30000,
  verbose = false,
  coverage = false,
}

function M.setup()
  local has_marker_groups, marker_groups = pcall(require, "marker-groups")
  if not has_marker_groups then
    error "marker-groups plugin not found. Ensure it's properly installed for testing."
  end

  if not marker_groups.is_initialized() then
    marker_groups.setup {
      data_dir = vim.fn.tempname() .. "_marker_groups_test",
      log_level = "debug",
      keymaps = { enabled = false },
    }
  end

  print "Test environment initialized"
end

function M.teardown()
  local config = require "marker-groups.config"
  local data_dir = config.get_value "data_dir"

  if data_dir and vim.fn.isdirectory(data_dir) == 1 then
    vim.fn.delete(data_dir, "rf")
  end

  print "Test environment cleaned up"
end

function M.run_suite(suite_type, opts)
  opts = vim.tbl_extend("force", M.config, opts or {})

  local pattern = M.config.test_patterns[suite_type]
  if not pattern then
    error("Unknown test suite: " .. suite_type)
  end

  print("Running " .. suite_type .. " tests...")
  print("Pattern: " .. pattern)

  M.setup()

  local test_harness = require "plenary.test_harness"

  local results = test_harness.test_directory(vim.fn.expand(pattern), {
    timeout = opts.timeout,
    verbose = opts.verbose,
  })

  M.teardown()

  return results
end

function M.run_all(opts)
  return M.run_suite("all", opts)
end

function M.run_unit(opts)
  return M.run_suite("unit", opts)
end

function M.run_integration(opts)
  return M.run_suite("integration", opts)
end

function M.run_file(test_file, opts)
  opts = vim.tbl_extend("force", M.config, opts or {})

  local file_path = Path:new(test_file)
  if not file_path:exists() then
    error("Test file not found: " .. test_file)
  end

  print("Running test file: " .. test_file)

  M.setup()

  local test_harness = require "plenary.test_harness"
  local results = test_harness.test_directory(test_file, {
    timeout = opts.timeout,
    verbose = opts.verbose,
  })

  M.teardown()

  return results
end

function M.watch(suite_type)
  suite_type = suite_type or "all"

  print("Watching " .. suite_type .. " tests for changes...")
  print "Press Ctrl+C to stop watching"

  local last_run = os.time()

  while true do
    vim.wait(1000)

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
      print "\nTest files changed, re-running tests..."
      M.run_suite(suite_type, { verbose = true })
      last_run = os.time()
    end
  end
end

function M.coverage()
  print "Coverage reporting not yet implemented"
  print "Consider using luacov or similar tools for Lua code coverage"
end

function M.register_commands()
  vim.api.nvim_create_user_command("MarkerGroupsTestAll", function()
    M.run_all { verbose = true }
  end, {
    desc = "Run all marker-groups tests",
  })

  vim.api.nvim_create_user_command("MarkerGroupsTestUnit", function()
    M.run_unit { verbose = true }
  end, {
    desc = "Run marker-groups unit tests",
  })

  vim.api.nvim_create_user_command("MarkerGroupsTestIntegration", function()
    M.run_integration { verbose = true }
  end, {
    desc = "Run marker-groups integration tests",
  })

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
    end,
  })

  vim.api.nvim_create_user_command("MarkerGroupsTestWatch", function(args)
    local suite = args.args ~= "" and args.args or "all"
    M.watch(suite)
  end, {
    nargs = "?",
    desc = "Watch tests for changes and re-run",
    complete = function()
      return { "all", "unit", "integration" }
    end,
  })
end

return M
