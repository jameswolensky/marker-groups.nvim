local M = {}

M.config = {
  default_timeout = 5000,
  integration_timeout = 10000,

  test_data_dir = vim.fn.tempname() .. "_marker_groups_tests",

  plugin_config = {
    data_dir = nil,
    log_level = "debug",
    keymaps = { enabled = false },
    debug = true,
  },

  cleanup_on_exit = true,
  preserve_logs = false,
}

function M.setup()
  M.config.plugin_config.data_dir = M.config.test_data_dir

  if vim.fn.isdirectory(M.config.test_data_dir) == 1 then
    vim.fn.delete(M.config.test_data_dir, "rf")
  end

  vim.fn.mkdir(M.config.test_data_dir, "p")

  local marker_groups = require "marker-groups"
  marker_groups.setup(M.config.plugin_config)

  print("Test environment initialized at: " .. M.config.test_data_dir)
end

function M.teardown()
  if M.config.cleanup_on_exit and vim.fn.isdirectory(M.config.test_data_dir) == 1 then
    vim.fn.delete(M.config.test_data_dir, "rf")
    print "Test environment cleaned up"
  end
end

function M.create_test_marker(overrides)
  local defaults = {
    buffer_path = vim.fn.expand "%:p",
    start_line = 1,
    end_line = 1,
    annotation = "Test marker",
    timestamp = os.time(),
  }

  return vim.tbl_extend("force", defaults, overrides or {})
end

function M.create_temp_file(content, extension)
  extension = extension or "lua"
  content = content or "local M = {}\nreturn M"

  local filepath = M.config.test_data_dir .. "/test_file_" .. os.time() .. "." .. extension

  local file = io.open(filepath, "w")
  if file then
    file:write(content)
    file:close()
  end

  return filepath
end

function M.wait_for(condition, timeout, interval)
  timeout = timeout or 1000
  interval = interval or 10

  local start_time = vim.loop.hrtime()
  local timeout_ns = timeout * 1000000

  while (vim.loop.hrtime() - start_time) < timeout_ns do
    if condition() then
      return true
    end
    vim.wait(interval)
  end

  return false
end

function M.assert_error(func, expected_error)
  local success, err = pcall(func)

  assert(not success, "Expected function to throw an error, but it succeeded")

  if expected_error then
    assert(
      type(err) == "string" and string.match(err, expected_error),
      "Error message '" .. tostring(err) .. "' does not match expected pattern '" .. expected_error .. "'"
    )
  end
end

function M.get_stats()
  return {
    test_data_dir = M.config.test_data_dir,
    temp_files_created = #vim.fn.glob(M.config.test_data_dir .. "/test_file_*", false, true),
    memory_usage = collectgarbage "count",
    timestamp = os.date "%Y-%m-%d %H:%M:%S",
  }
end

return M
