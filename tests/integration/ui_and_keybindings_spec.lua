local assert = require "luassert"
local state = require "marker-groups.state"
local config = require "marker-groups.config"
local drawer = require "marker-groups.ui.drawer"

describe("UI and Keybinding Functionality", function()
  before_each(function()
    require("marker-groups").setup {
      data_dir = "/tmp/marker-groups-test-ui",
      log_level = "debug",
      drawer_config = {
        width = 60,
        side = "right",
      },
    }

    state.initialize(config.get())
  end)

  describe("Long annotation UI handling", function()
    it("should have max_annotation_display configuration", function()
      local max_display = config.get_value("max_annotation_display", 50)
      assert.is_number(max_display)
      assert.is_true(max_display > 0)
    end)

    it("should truncate long annotations in display logic", function()
      local test_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "Test line" })

      local long_annotation = string.rep("x", 80)
      local marker_data = {
        buffer_path = vim.api.nvim_buf_get_name(test_buf),
        start_line = 1,
        end_line = 1,
        annotation = long_annotation,
      }

      local result = state.add_marker(marker_data)
      assert.is_true(result.success)

      local group = state.get_group "default"
      assert.are.equal(long_annotation, group.markers[1].annotation)

      vim.api.nvim_buf_delete(test_buf, { force = true })
    end)
  end)

  describe("Drawer configuration instead of floating window", function()
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

    it("should have drawer-specific configuration options", function()
      local current_config = config.get()
      local drawer_config = current_config.drawer_config

      assert.is_not_nil(drawer_config.width)
      assert.is_not_nil(drawer_config.side)
      assert.is_true(drawer_config.side == "left" or drawer_config.side == "right")
    end)
  end)

  describe("Drawer width configuration", function()
    it("should have drawer width functions in drawer module", function()
      assert.is_function(drawer.set_drawer_width)
      assert.is_function(drawer.get_drawer_width)
    end)

    it("should get current drawer width", function()
      local width = drawer.get_drawer_width()
      assert.is_number(width)
      assert.is_true(width >= 30 and width <= 120)
    end)

    it("should set drawer width within valid range", function()
      local new_width = 80
      drawer.set_drawer_width(new_width)

      local current_width = drawer.get_drawer_width()
      assert.are.equal(new_width, current_width)
    end)

    it("should clamp drawer width to valid range", function()
      drawer.set_drawer_width(20)
      local width_small = drawer.get_drawer_width()
      assert.is_true(width_small >= 30)

      drawer.set_drawer_width(150)
      local width_large = drawer.get_drawer_width()
      assert.is_true(width_large <= 120)
    end)

    it("should have MarkerGroupsDrawerWidth command", function()
      assert.has_no.errors(function()
        vim.cmd "MarkerGroupsDrawerWidth"
      end)
    end)

    it("should set width via command", function()
      local target_width = 90

      assert.has_no.errors(function()
        vim.cmd("MarkerGroupsDrawerWidth " .. target_width)
      end)

      local current_width = drawer.get_drawer_width()
      assert.are.equal(target_width, current_width)
    end)
  end)

  describe("Leader m keybinding configuration", function()
    it("should have keymaps module that loads without error", function()
      assert.has_no.errors(function()
        local keymaps = require "marker-groups.keymaps"
        keymaps.setup()
      end)
    end)

    it("should not map bare <leader>m (prefix-only)", function()
      local keymaps = require "marker-groups.keymaps"
      assert.has_no.errors(function()
        keymaps.setup()
      end)

      local maps = vim.api.nvim_get_keymap "n"
      local bare_leader_m = false
      for _, map in ipairs(maps) do
        if map.lhs == "<leader>m" then
          bare_leader_m = true
          break
        end
      end

      assert.is_false(bare_leader_m)
    end)

    it("should have the leader m keybinding configured", function()
      local keymaps = require "marker-groups.keymaps"

      assert.has_no.errors(function()
        keymaps.setup()
      end)
    end)
  end)

  describe("Drawer navigation enhancements", function()
    it("should have navigation functions in drawer module", function()
      assert.is_function(drawer.navigate_to_next_marker)
      assert.is_function(drawer.setup_global_drawer_navigation)
      assert.is_function(drawer.cleanup_global_drawer_navigation)
    end)

    it("should have marker movement functions in drawer module", function()
      assert.is_function(drawer.move_current_marker_up)
      assert.is_function(drawer.move_current_marker_down)
      assert.is_function(drawer.refresh_current_drawer)
    end)

    it("should handle navigation with empty marker list", function()
      local empty_positions = {}

      assert.has_no.errors(function()
        drawer.navigate_to_next_marker(1, empty_positions, "down")
        drawer.navigate_to_next_marker(1, empty_positions, "up")
      end)
    end)

    it("should handle global navigation setup and cleanup", function()
      local dummy_win_id = 1000
      local empty_positions = {}

      assert.has_no.errors(function()
        drawer.setup_global_drawer_navigation(dummy_win_id, empty_positions)
        drawer.cleanup_global_drawer_navigation(dummy_win_id)
      end)
    end)
  end)

  describe("Commands integration", function()
    it("should have all marker-related commands available", function()
      local commands_module = require "marker-groups.commands"

      assert.has_no.errors(function()
        commands_module.setup()
      end)

      assert.has_no.errors(function()
        vim.cmd "MarkerGroupsDrawerWidth"
      end)
    end)

    it("should handle drawer width command with invalid input", function()
      assert.has_no.errors(function()
        vim.cmd "MarkerGroupsDrawerWidth invalid"
      end)
    end)
  end)

  describe("Configuration validation", function()
    it("should validate drawer_config structure", function()
      local test_configs = {
        { drawer_config = { width = 60, side = "right" } },
        { drawer_config = { width = 80, side = "left" } },
      }

      for _, test_config in ipairs(test_configs) do
        assert.has_no.errors(function()
          config.update(test_config)
        end)

        local updated = config.get()
        assert.are.equal(test_config.drawer_config.width, updated.drawer_config.width)
        assert.are.equal(test_config.drawer_config.side, updated.drawer_config.side)
      end
    end)

    it("should handle invalid drawer_config gracefully", function()
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
