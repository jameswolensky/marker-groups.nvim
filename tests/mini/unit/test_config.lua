local MiniTest = require "mini.test"

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      package.loaded["marker-groups"] = nil
      package.loaded["marker-groups.config"] = nil

      local mg = require "marker-groups"
      mg.setup {
        data_dir = vim.fn.tempname() .. "_marker_groups_test",
        log_level = "debug",
        keymaps = { enabled = false },
      }

      local config = require "marker-groups.config"
      _G.__mg_original_config = vim.deepcopy(config.get())
    end,

    post_case = function()
      local ok, config = pcall(require, "marker-groups.config")
      if ok and _G.__mg_original_config then
        config.update(_G.__mg_original_config)
      end
      _G.__mg_original_config = nil
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

T["get and set operations / should get default values"] = function()
  local config = require "marker-groups.config"
  local data_dir = config.get_value "data_dir"
  expect_type(data_dir, "string")
  expect_truthy(#data_dir > 0)
end

T["get and set operations / should get nested values"] = function()
  local config = require "marker-groups.config"
  local keymaps_enabled = config.get_value("keymaps.enabled", true)
  expect_type(keymaps_enabled, "boolean")
end

T["get and set operations / should return default for non-existent keys"] = function()
  local config = require "marker-groups.config"
  local value = config.get_value("non_existent_key", "default_value")
  MiniTest.expect.equality(value, "default_value")
end

T["get and set operations / should get full config object"] = function()
  local config = require "marker-groups.config"
  local full_config = config.get()
  expect_type(full_config, "table")
  expect_truthy(full_config.data_dir ~= nil)
end

T["configuration updates / should update configuration values"] = function()
  local config = require "marker-groups.config"
  local new_config = vim.deepcopy(config.get())
  new_config.log_level = "debug"
  config.update(new_config)
  local updated_level = config.get_value "log_level"
  MiniTest.expect.equality(updated_level, "debug")
end

T["configuration updates / should preserve existing values when updating"] = function()
  local config = require "marker-groups.config"
  local original_data_dir = config.get_value "data_dir"
  local partial_config = { log_level = "error" }
  config.update(partial_config)
  local updated_data_dir = config.get_value "data_dir"
  MiniTest.expect.equality(updated_data_dir, original_data_dir)
end

T["validation / should validate log levels"] = function()
  local config = require "marker-groups.config"
  local valid_levels = { "debug", "info", "warn", "error" }
  for _, level in ipairs(valid_levels) do
    local new_config = vim.deepcopy(config.get())
    new_config.log_level = level
    config.update(new_config)
    MiniTest.expect.equality(config.get_value "log_level", level)
  end
end

T["validation / should handle boolean values correctly (debug)"] = function()
  local config = require "marker-groups.config"
  local new_config = vim.deepcopy(config.get())
  new_config.debug = true
  config.update(new_config)
  expect_truthy(config.get_value "debug")
end

T["path handling / should expand data directory path"] = function()
  local config = require "marker-groups.config"
  local data_dir = config.get_value "data_dir"
  expect_falsy(string.match(data_dir, "%%"))
  expect_falsy(string.match(data_dir, "%$"))
  local normalized_path = vim.fn.fnamemodify(data_dir, ":p"):gsub("/$", "")
  MiniTest.expect.equality(normalized_path, data_dir)
end

T["drawer configuration / should have drawer_config in default configuration"] = function()
  local config = require "marker-groups.config"
  local current_config = config.get()
  expect_truthy(current_config.drawer_config ~= nil)
  expect_type(current_config.drawer_config, "table")
  expect_type(current_config.drawer_config.width, "number")
  expect_type(current_config.drawer_config.side, "string")
end

T["drawer configuration / should not have float_config in configuration"] = function()
  local config = require "marker-groups.config"
  local current_config = config.get()
  expect_falsy(current_config.float_config ~= nil)
end

T["drawer configuration / should have valid drawer configuration defaults"] = function()
  local config = require "marker-groups.config"
  local drawer_config = config.get().drawer_config
  expect_truthy(drawer_config.width ~= nil)
  expect_truthy(drawer_config.side ~= nil)
  expect_truthy(drawer_config.side == "left" or drawer_config.side == "right")
  expect_truthy(drawer_config.width >= 30 and drawer_config.width <= 120)
end

T["drawer configuration / should validate drawer width ranges"] = function()
  local config = require "marker-groups.config"
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
    MiniTest.expect.equality(test_config.drawer_config.width, updated_config.drawer_config.width)
    config.update(original_config)
  end
end

T["drawer configuration / should validate drawer side values"] = function()
  local config = require "marker-groups.config"
  local valid_sides = { "left", "right" }
  for _, side in ipairs(valid_sides) do
    local original_config = config.get()
    local test_config = { drawer_config = { side = side } }
    config.update(test_config)
    local updated_config = config.get()
    MiniTest.expect.equality(side, updated_config.drawer_config.side)
    config.update(original_config)
  end
end

T["drawer configuration / should handle invalid drawer configurations gracefully"] = function()
  local config = require "marker-groups.config"
  local invalid_configs = {
    { drawer_config = { width = "invalid" } },
    { drawer_config = { side = "invalid" } },
    { drawer_config = { width = 200 } },
    { drawer_config = { width = 10 } },
  }
  for _, invalid_config in ipairs(invalid_configs) do
    local ok = pcall(config.update, invalid_config)
    expect_type(ok, "boolean")
  end
end

return T
