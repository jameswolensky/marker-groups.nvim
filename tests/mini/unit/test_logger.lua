local MiniTest = require "mini.test"

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      package.loaded["marker-groups"] = nil
      package.loaded["marker-groups.utils.logger"] = nil
      require("marker-groups").setup { data_dir = vim.fn.tempname() .. "_mg_log", log_level = "debug" }
      local logger = require "marker-groups.utils.logger"
      logger.setup(true)
      logger.clear()
    end,
  },
}

local expect_truthy = MiniTest.new_expectation("truthy", function(x)
  return not not x
end, function(x)
  return "Object: " .. vim.inspect(x)
end)
local expect_falsy = MiniTest.new_expectation("falsy", function(x)
  return not x
end, function(x)
  return "Object: " .. vim.inspect(x)
end)
local expect_type = MiniTest.new_expectation("type", function(x, t)
  return type(x) == t
end, function(x, t)
  return string.format("Expected %s, got %s. Object: %s", t, type(x), vim.inspect(x))
end)

T["initialization / should initialize and create log buffer"] = function()
  local logger = require "marker-groups.utils.logger"
  logger.setup(true)
  local status = logger.get_status()
  expect_truthy(status.initialized)
  expect_truthy(status.buffer_valid)
  expect_type(status.current_level, "string")
  expect_type(status.buffer_id, "number")
  expect_truthy(vim.api.nvim_buf_is_valid(status.buffer_id))
end

T["log levels / get, set, reject invalid"] = function()
  local logger = require "marker-groups.utils.logger"
  local level = logger.get_level()
  expect_type(level, "string")
  expect_truthy(vim.tbl_contains({ "debug", "info", "warn", "error" }, level))
  expect_truthy(logger.set_level "debug")
  MiniTest.expect.equality("debug", logger.get_level())
  MiniTest.expect.equality(false, logger.set_level "invalid")
end

T["logging functions / debug, info, warn, error"] = function()
  local logger = require "marker-groups.utils.logger"
  logger.set_level "debug"
  logger.debug "Test debug message"
  logger.info "Test info message"
  logger.warn "Test warning message"
  logger.error "Test error message"
  local logs = logger.get_logs()
  local found = { debug = false, info = false, warn = false, error = false }
  for _, line in ipairs(logs) do
    if string.match(line, "DEBUG.*Test debug message") then
      found.debug = true
    end
    if string.match(line, "INFO.*Test info message") then
      found.info = true
    end
    if string.match(line, "WARN.*Test warning message") then
      found.warn = true
    end
    if string.match(line, "ERROR.*Test error message") then
      found.error = true
    end
  end
  expect_truthy(found.debug and found.info and found.warn and found.error)
end

T["log filtering / respect level"] = function()
  local logger = require "marker-groups.utils.logger"
  logger.set_level "warn"
  logger.clear()
  logger.debug "Debug message"
  logger.info "Info message"
  logger.warn "Warning message"
  logger.error "Error message"
  local logs = logger.get_logs()
  local debug_found, info_found, warn_found, error_found = false, false, false, false
  for _, line in ipairs(logs) do
    if string.match(line, "DEBUG") then
      debug_found = true
    end
    if string.match(line, "INFO") then
      info_found = true
    end
    if string.match(line, "WARN") then
      warn_found = true
    end
    if string.match(line, "ERROR") then
      error_found = true
    end
  end
  expect_falsy(debug_found)
  expect_falsy(info_found)
  expect_truthy(warn_found)
  expect_truthy(error_found)
end

T["buffer management / clear preserves header and limits size"] = function()
  local logger = require "marker-groups.utils.logger"
  logger.info "Test message before clear"
  logger.clear()
  local logs = logger.get_logs()
  local has_header = false
  for _, line in ipairs(logs) do
    if string.match(line, "Marker Groups Plugin Log") then
      has_header = true
      break
    end
  end
  expect_truthy(has_header)
  logger.set_level "debug"
  logger.clear()
  for i = 1, 1100 do
    logger.debug("Test message " .. i)
  end
  logs = logger.get_logs()
  expect_truthy(#logs <= 1010)
end

T["status reporting / counts log entries"] = function()
  local logger = require "marker-groups.utils.logger"
  logger.clear()
  local initial = logger.get_status()
  logger.info "Message 1"
  logger.info "Message 2"
  local final = logger.get_status()
  MiniTest.expect.equality(initial.log_count + 2, final.log_count)
end

return T
