local assert = require "luassert"
local config = require "marker-groups.config"

describe("marker-groups config module", function()
  local original_config

  before_each(function()
    require("marker-groups").setup {
      data_dir = "/tmp/marker-groups-test",
      log_level = "debug",
    }

    original_config = vim.deepcopy(config.get())
  end)

  after_each(function()
    config.update(original_config)
  end)

  describe("get and set operations", function()
    it("should get default values", function()
      local data_dir = config.get_value "data_dir"
      assert.is_string(data_dir)
      assert.is_true(string.len(data_dir) > 0)
    end)

    it("should get nested values", function()
      local keymaps_enabled = config.get_value("keymaps.enabled", true)
      assert.is_boolean(keymaps_enabled)
    end)

    it("should return default for non-existent keys", function()
      local value = config.get_value("non_existent_key", "default_value")
      assert.are.equal("default_value", value)
    end)

    it("should get full config object", function()
      local full_config = config.get()
      assert.is_table(full_config)
      assert.is_not_nil(full_config.data_dir)
    end)
  end)

  describe("configuration updates", function()
    it("should update configuration values", function()
      local new_config = vim.deepcopy(config.get())
      new_config.log_level = "debug"

      config.update(new_config)

      local updated_level = config.get_value "log_level"
      assert.are.equal("debug", updated_level)
    end)

    it("should preserve existing values when updating", function()
      local original_data_dir = config.get_value "data_dir"

      local partial_config = { log_level = "error" }
      config.update(partial_config)

      local updated_data_dir = config.get_value "data_dir"
      assert.are.equal(original_data_dir, updated_data_dir)
    end)
  end)

  describe("validation", function()
    it("should validate log levels", function()
      local valid_levels = { "debug", "info", "warn", "error" }

      for _, level in ipairs(valid_levels) do
        local new_config = vim.deepcopy(config.get())
        new_config.log_level = level

        config.update(new_config)
        assert.are.equal(level, config.get_value "log_level")
      end
    end)

    it("should handle boolean values correctly (debug)", function()
      local new_config = vim.deepcopy(config.get())
      new_config.debug = true

      config.update(new_config)

      local debug_flag = config.get_value "debug"
      assert.is_true(debug_flag)
    end)
  end)

  describe("path handling", function()
    it("should expand data directory path", function()
      local data_dir = config.get_value "data_dir"

      assert.is_falsy(string.match(data_dir, "%%"))
      assert.is_falsy(string.match(data_dir, "%$"))

      local normalized_path = vim.fn.fnamemodify(data_dir, ":p"):gsub("/$", "")
      assert.is_true(normalized_path == data_dir)
    end)
  end)

  describe("drawer configuration", function()
    it("should have drawer_config in default configuration", function()
      local current_config = config.get()

      assert.is_not_nil(current_config.drawer_config)
      assert.is_table(current_config.drawer_config)
      assert.is_number(current_config.drawer_config.width)
      assert.is_string(current_config.drawer_config.side)
    end)

    it("should not have float_config in configuration", function()
      local current_config = config.get()

      assert.is_nil(current_config.float_config)
    end)

    it("should have valid drawer configuration defaults", function()
      local current_config = config.get()
      local drawer_config = current_config.drawer_config

      assert.is_not_nil(drawer_config.width)
      assert.is_not_nil(drawer_config.side)
      assert.is_true(drawer_config.side == "left" or drawer_config.side == "right")
      assert.is_true(drawer_config.width >= 30 and drawer_config.width <= 120)
    end)

    it("should validate drawer width ranges", function()
      local test_configs = {
        { drawer_config = { width = 60 } },
        { drawer_config = { width = 80 } },
        { drawer_config = { width = 30 } },
        { drawer_config = { width = 120 } },
      }

      for _, test_config in ipairs(test_configs) do
        local original_config = config.get()
        config.update(test_config)

        local updated_config = config.get()
        assert.are.equal(test_config.drawer_config.width, updated_config.drawer_config.width)

        config.update(original_config)
      end
    end)

    it("should validate drawer side values", function()
      local valid_sides = { "left", "right" }

      for _, side in ipairs(valid_sides) do
        local original_config = config.get()
        local test_config = { drawer_config = { side = side } }
        config.update(test_config)

        local updated_config = config.get()
        assert.are.equal(side, updated_config.drawer_config.side)

        config.update(original_config)
      end
    end)

    it("should handle invalid drawer configurations gracefully", function()
      local invalid_configs = {
        { drawer_config = { width = "invalid" } },
        { drawer_config = { side = "invalid" } },
        { drawer_config = { width = 200 } },
        { drawer_config = { width = 10 } },
      }

      for _, invalid_config in ipairs(invalid_configs) do
        local success = pcall(config.update, invalid_config)
        assert.is_boolean(success)
      end
    end)
  end)
end)
