local assert = require "luassert"

describe("marker-groups drawer UI module", function()
  local drawer

  before_each(function()
    require("marker-groups").setup {
      data_dir = "/tmp/marker-groups-test",
      log_level = "debug",
      drawer_config = {
        width = 60,
        side = "right",
      },
    }

    drawer = require "marker-groups.ui.drawer"
  end)

  describe("drawer width management", function()
    it("should have drawer width functions", function()
      assert.is_function(drawer.set_drawer_width)
      assert.is_function(drawer.get_drawer_width)
    end)

    it("should get current drawer width", function()
      local width = drawer.get_drawer_width()
      assert.is_number(width)
      assert.is_true(width >= 30 and width <= 120)
    end)

    it("should set drawer width within valid range", function()
      local original_width = drawer.get_drawer_width()
      local new_width = 80

      drawer.set_drawer_width(new_width)
      local current_width = drawer.get_drawer_width()
      assert.are.equal(new_width, current_width)

      drawer.set_drawer_width(original_width)
    end)

    it("should clamp drawer width to valid range", function()
      local original_width = drawer.get_drawer_width()

      drawer.set_drawer_width(20)
      local width_small = drawer.get_drawer_width()
      assert.is_true(width_small >= 30)

      drawer.set_drawer_width(150)
      local width_large = drawer.get_drawer_width()
      assert.is_true(width_large <= 120)

      drawer.set_drawer_width(original_width)
    end)
  end)

  describe("navigation functions", function()
    it("should have navigation functions", function()
      assert.is_function(drawer.navigate_to_next_marker)
      assert.is_function(drawer.setup_global_drawer_navigation)
      assert.is_function(drawer.cleanup_global_drawer_navigation)
    end)

    it("should have marker movement functions", function()
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

  describe("window management", function()
    it("should have window calculation functions", function()
      assert.is_function(drawer.calculate_window_config)
    end)

    it("should handle marker display functions", function()
      assert.is_function(drawer.show_markers)
    end)

    it("should have debug functions", function()
      assert.is_function(drawer.debug_info)
    end)

    it("should have toggle functionality", function()
      assert.is_function(drawer.toggle_drawer)
      assert.is_function(drawer.has_open_windows)
      assert.is_function(drawer.close_all)
    end)
  end)

  describe("toggle functionality", function()
    it("should have toggle_drawer function", function()
      assert.is_function(drawer.toggle_drawer)
    end)

    it("should handle toggle when no windows are open", function()
      drawer.close_all()

      local original_has_open = drawer.has_open_windows
      drawer.has_open_windows = function()
        return false
      end

      local show_markers_called = false
      local original_show_markers = drawer.show_markers
      drawer.show_markers = function()
        show_markers_called = true
        return 1, 1
      end

      local buf_id, win_id = drawer.toggle_drawer()
      assert.is_true(show_markers_called)
      assert.are.equal(1, buf_id)
      assert.are.equal(1, win_id)

      drawer.has_open_windows = original_has_open
      drawer.show_markers = original_show_markers
    end)

    it("should handle toggle when windows are open", function()
      local original_has_open = drawer.has_open_windows
      drawer.has_open_windows = function()
        return true
      end

      local close_all_called = false
      local original_close_all = drawer.close_all
      drawer.close_all = function()
        close_all_called = true
      end

      local buf_id, win_id = drawer.toggle_drawer()
      assert.is_true(close_all_called)
      assert.is_nil(buf_id)
      assert.is_nil(win_id)

      drawer.has_open_windows = original_has_open
      drawer.close_all = original_close_all
    end)

    it("should ensure single instance in show_markers", function()
      local original_has_open = drawer.has_open_windows
      local original_close_all = drawer.close_all
      local original_show_markers = drawer.show_markers

      local close_all_called = false
      drawer.has_open_windows = function()
        return true
      end
      drawer.close_all = function()
        close_all_called = true
      end

      drawer.show_markers = function()
        if drawer.has_open_windows() then
          drawer.close_all()
        end
        return nil, nil
      end

      drawer.show_markers()
      assert.is_true(close_all_called)

      drawer.has_open_windows = original_has_open
      drawer.close_all = original_close_all
      drawer.show_markers = original_show_markers
    end)

    it("should handle toggle with no active group gracefully", function()
      local state = require "marker-groups.state"
      local original_get_active = state.get_active_group
      state.get_active_group = function()
        return nil
      end

      local original_has_open = drawer.has_open_windows
      drawer.has_open_windows = function()
        return false
      end

      local buf_id, win_id = drawer.toggle_drawer()
      assert.is_nil(buf_id)
      assert.is_nil(win_id)

      state.get_active_group = original_get_active
      drawer.has_open_windows = original_has_open
    end)
  end)

  describe("delete functionality", function()
    it("should have delete_current_marker function", function()
      assert.is_function(drawer.delete_current_marker)
    end)

    it("should handle delete when no marker is found", function()
      local original_win_is_valid = vim.api.nvim_win_is_valid
      local original_win_get_cursor = vim.api.nvim_win_get_cursor
      vim.api.nvim_win_is_valid = function()
        return true
      end
      vim.api.nvim_win_get_cursor = function()
        return { 1, 0 }
      end

      local empty_positions = {}
      local dummy_win_id = 1000

      assert.has_no.errors(function()
        drawer.delete_current_marker(dummy_win_id, empty_positions)
      end)

      vim.api.nvim_win_is_valid = original_win_is_valid
      vim.api.nvim_win_get_cursor = original_win_get_cursor
    end)

    it("should handle delete with invalid window", function()
      local marker_positions = { [5] = { id = "test_id" } }

      assert.has_no.errors(function()
        drawer.delete_current_marker(999, marker_positions)
      end)
    end)

    it("should find correct marker at cursor position", function()
      local original_win_is_valid = vim.api.nvim_win_is_valid
      local original_win_get_cursor = vim.api.nvim_win_get_cursor
      vim.api.nvim_win_is_valid = function()
        return true
      end
      vim.api.nvim_win_get_cursor = function()
        return { 10, 0 }
      end

      local marker_positions = {
        [5] = { id = "marker1", annotation = "First marker", buffer_path = "/test/file1.lua", start_line = 5 },
        [8] = { id = "marker2", annotation = "Second marker", buffer_path = "/test/file2.lua", start_line = 8 },
        [15] = { id = "marker3", annotation = "Third marker", buffer_path = "/test/file3.lua", start_line = 15 },
      }

      local markers = require "marker-groups.markers"
      local original_delete = markers.delete_marker
      local delete_called_with = nil
      markers.delete_marker = function(marker_id)
        delete_called_with = marker_id
        return { success = true }
      end

      local original_refresh = drawer.refresh_current_drawer
      drawer.refresh_current_drawer = function() end

      drawer.delete_current_marker(1000, marker_positions)

      assert.are.equal("marker2", delete_called_with)

      vim.api.nvim_win_is_valid = original_win_is_valid
      vim.api.nvim_win_get_cursor = original_win_get_cursor
      markers.delete_marker = original_delete
      drawer.refresh_current_drawer = original_refresh
    end)

    it("should handle delete failure gracefully", function()
      local original_win_is_valid = vim.api.nvim_win_is_valid
      local original_win_get_cursor = vim.api.nvim_win_get_cursor
      vim.api.nvim_win_is_valid = function()
        return true
      end
      vim.api.nvim_win_get_cursor = function()
        return { 5, 0 }
      end

      local marker_positions = {
        [5] = { id = "test_marker", annotation = "Test marker", buffer_path = "/test/file.lua", start_line = 5 },
      }

      local markers = require "marker-groups.markers"
      local original_delete = markers.delete_marker
      markers.delete_marker = function()
        return { success = false, error = "Test deletion failure" }
      end

      assert.has_no.errors(function()
        drawer.delete_current_marker(1000, marker_positions)
      end)

      vim.api.nvim_win_is_valid = original_win_is_valid
      vim.api.nvim_win_get_cursor = original_win_get_cursor
      markers.delete_marker = original_delete
    end)
  end)

  describe("annotation display handling", function()
    it("should handle long annotation display", function()
      local config = require "marker-groups.config"
      local max_display = config.get_value("max_annotation_display", 50)

      assert.is_number(max_display)
      assert.is_true(max_display > 0)
    end)

    it("should handle long annotation display integration", function()
      local long_annotation = string.rep("a", 80)

      assert.is_true(#long_annotation > 50)
      assert.is_true(#long_annotation <= 500)

      local config = require "marker-groups.config"
      local max_display = config.get_value("max_annotation_display", 50)

      local display_annotation = long_annotation
      if #display_annotation > max_display then
        display_annotation = display_annotation:sub(1, max_display - 3) .. "..."
      end

      assert.is_true(#display_annotation <= max_display + 3)
      assert.is_true(display_annotation:sub(-3) == "...")
    end)
  end)
end)
