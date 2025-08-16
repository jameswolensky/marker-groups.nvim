local assert = require "luassert"
local logger = require "marker-groups.utils.logger"

describe("marker-groups logger module", function()
  before_each(function()
    require("marker-groups").setup {
      data_dir = "/tmp/marker-groups-test",
      log_level = "debug",
    }

    logger.setup(true)
    logger.clear()
  end)

  describe("initialization", function()
    it("should initialize successfully", function()
      logger.setup(true)
      local status = logger.get_status()

      assert.is_true(status.initialized)
      assert.is_true(status.buffer_valid)
      assert.is_string(status.current_level)
    end)

    it("should create log buffer", function()
      logger.setup(true)
      local status = logger.get_status()

      assert.is_number(status.buffer_id)
      assert.is_true(vim.api.nvim_buf_is_valid(status.buffer_id))
    end)
  end)

  describe("log levels", function()
    it("should get current log level", function()
      local level = logger.get_level()

      assert.is_string(level)
      assert.is_true(vim.tbl_contains({ "debug", "info", "warn", "error" }, level))
    end)

    it("should set log level", function()
      local success = logger.set_level "debug"

      assert.is_true(success)
      assert.are.equal("debug", logger.get_level())
    end)

    it("should reject invalid log levels", function()
      local success = logger.set_level "invalid"

      assert.is_false(success)
    end)
  end)

  describe("logging functions", function()
    it("should log debug messages", function()
      logger.set_level "debug"
      logger.debug "Test debug message"

      local logs = logger.get_logs()
      local found = false

      for _, line in ipairs(logs) do
        if string.match(line, "DEBUG.*Test debug message") then
          found = true
          break
        end
      end

      assert.is_true(found)
    end)

    it("should log info messages", function()
      logger.set_level "info"
      logger.info "Test info message"

      local logs = logger.get_logs()
      local found = false

      for _, line in ipairs(logs) do
        if string.match(line, "INFO.*Test info message") then
          found = true
          break
        end
      end

      assert.is_true(found)
    end)

    it("should log warning messages", function()
      logger.warn "Test warning message"

      local logs = logger.get_logs()
      local found = false

      for _, line in ipairs(logs) do
        if string.match(line, "WARN.*Test warning message") then
          found = true
          break
        end
      end

      assert.is_true(found)
    end)

    it("should log error messages", function()
      logger.error "Test error message"

      local logs = logger.get_logs()
      local found = false

      for _, line in ipairs(logs) do
        if string.match(line, "ERROR.*Test error message") then
          found = true
          break
        end
      end

      assert.is_true(found)
    end)

    it("should respect log level filtering", function()
      logger.set_level "warn"
      logger.clear()

      logger.debug "Debug message"
      logger.info "Info message"
      logger.warn "Warning message"
      logger.error "Error message"

      local logs = logger.get_logs()
      local debug_found = false
      local info_found = false
      local warn_found = false
      local error_found = false

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

      assert.is_false(debug_found)
      assert.is_false(info_found)
      assert.is_true(warn_found)
      assert.is_true(error_found)
    end)
  end)

  describe("log buffer management", function()
    it("should clear log buffer", function()
      logger.info "Test message before clear"
      logger.clear()

      local logs = logger.get_logs()
      local has_test_message = false

      for _, line in ipairs(logs) do
        if string.match(line, "Test message before clear") then
          has_test_message = true
          break
        end
      end

      assert.is_false(has_test_message)
    end)

    it("should preserve header after clear", function()
      logger.clear()

      local logs = logger.get_logs()
      local has_header = false

      for _, line in ipairs(logs) do
        if string.match(line, "Marker Groups Plugin Log") then
          has_header = true
          break
        end
      end

      assert.is_true(has_header)
    end)

    it("should limit buffer size", function()
      logger.set_level "debug"
      logger.clear()

      for i = 1, 1100 do
        logger.debug("Test message " .. i)
      end

      local logs = logger.get_logs()
      assert.is_true(#logs <= 1010)
    end)
  end)

  describe("status reporting", function()
    it("should return accurate status", function()
      logger.setup(true)
      local status = logger.get_status()

      assert.is_table(status)
      assert.is_boolean(status.initialized)
      assert.is_boolean(status.buffer_valid)
      assert.is_string(status.current_level)
      assert.is_table(status.available_levels)
      assert.is_number(status.log_count)
    end)

    it("should count log entries correctly", function()
      logger.clear()
      local initial_status = logger.get_status()

      logger.info "Message 1"
      logger.info "Message 2"

      local final_status = logger.get_status()

      assert.are.equal(initial_status.log_count + 2, final_status.log_count)
    end)
  end)
end)
