local MiniTest = require "mini.test"

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      package.loaded["marker-groups"] = nil
      package.loaded["marker-groups.ui.drawer"] = nil
      package.loaded["marker-groups.config"] = nil
      package.loaded["marker-groups.state"] = nil

      require("marker-groups").setup {
        data_dir = vim.fn.tempname() .. "_marker_groups_test",
        log_level = "debug",
        keymaps = { enabled = false },
        drawer_config = { width = 60, side = "right" },
      }
    end,
  },
}

-- Helpers
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

-- drawer width management
T["drawer width management / should have drawer width functions"] = function()
  local drawer = require "marker-groups.ui.drawer"
  expect_type(drawer.set_drawer_width, "function")
  expect_type(drawer.get_drawer_width, "function")
end

T["drawer width management / should get current drawer width"] = function()
  local drawer = require "marker-groups.ui.drawer"
  local width = drawer.get_drawer_width()
  expect_type(width, "number")
  expect_truthy(width >= 30 and width <= 120)
end

T["drawer width management / should set drawer width within valid range"] = function()
  local drawer = require "marker-groups.ui.drawer"
  local original_width = drawer.get_drawer_width()
  local new_width = 80
  drawer.set_drawer_width(new_width)
  local current = drawer.get_drawer_width()
  MiniTest.expect.equality(current, new_width)
  drawer.set_drawer_width(original_width)
end

T["drawer width management / should clamp drawer width to valid range"] = function()
  local drawer = require "marker-groups.ui.drawer"
  local original_width = drawer.get_drawer_width()

  drawer.set_drawer_width(20)
  local small = drawer.get_drawer_width()
  expect_truthy(small >= 30)

  drawer.set_drawer_width(150)
  local large = drawer.get_drawer_width()
  expect_truthy(large <= 120)

  drawer.set_drawer_width(original_width)
end

-- navigation functions
T["navigation functions / should have navigation functions"] = function()
  local drawer = require "marker-groups.ui.drawer"
  expect_type(drawer.navigate_to_next_marker, "function")
  expect_type(drawer.resize_window, "function")
  expect_type(drawer.jump_to_marker_location, "function")
end

T["navigation functions / should handle navigation with empty marker list"] = function()
  local drawer = require "marker-groups.ui.drawer"
  local empty = {}
  MiniTest.expect.no_error(function()
    drawer.navigate_to_next_marker(1, empty, "down")
  end)
  MiniTest.expect.no_error(function()
    drawer.navigate_to_next_marker(1, empty, "up")
  end)
end

-- window management
T["window management / should have window calculation functions"] = function()
  local drawer = require "marker-groups.ui.drawer"
  expect_type(drawer.calculate_window_config, "function")
end

T["window management / should handle marker display functions"] = function()
  local drawer = require "marker-groups.ui.drawer"
  expect_type(drawer.show_markers, "function")
end

T["window management / should have debug functions"] = function()
  local drawer = require "marker-groups.ui.drawer"
  expect_type(drawer.debug_info, "function")
end

-- toggle functionality
T["toggle functionality / should have toggle_drawer function"] = function()
  local drawer = require "marker-groups.ui.drawer"
  expect_type(drawer.toggle_drawer, "function")
end

T["toggle functionality / should handle toggle when no windows are open"] = function()
  local drawer = require "marker-groups.ui.drawer"
  local original_has_open = drawer.has_open_windows
  local original_show = drawer.show_markers
  drawer.has_open_windows = function()
    return false
  end
  local called = false
  drawer.show_markers = function()
    called = true
    return 1, 1
  end
  drawer.toggle_drawer()
  expect_truthy(called)
  drawer.has_open_windows = original_has_open
  drawer.show_markers = original_show
end

T["toggle functionality / should handle toggle when windows are open"] = function()
  local drawer = require "marker-groups.ui.drawer"
  local original_has_open = drawer.has_open_windows
  local original_close_all = drawer.close_all
  drawer.has_open_windows = function()
    return true
  end
  local closed = false
  drawer.close_all = function()
    closed = true
  end
  drawer.toggle_drawer()
  expect_truthy(closed)
  drawer.has_open_windows = original_has_open
  drawer.close_all = original_close_all
end

-- delete functionality
T["delete functionality / should have delete_current_marker function"] = function()
  local drawer = require "marker-groups.ui.drawer"
  expect_type(drawer.delete_current_marker, "function")
end

T["delete functionality / should handle delete when no marker is found"] = function()
  local drawer = require "marker-groups.ui.drawer"
  local empty_positions = {}
  MiniTest.expect.no_error(function()
    drawer.delete_current_marker(999, empty_positions)
  end)
end

T["delete functionality / should find correct marker at cursor position"] = function()
  local drawer = require "marker-groups.ui.drawer"
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
  local called_with = nil
  markers.delete_marker = function(id)
    called_with = id
    return { success = true }
  end

  local original_refresh = drawer.refresh_current_drawer
  drawer.refresh_current_drawer = function() end

  drawer.delete_current_marker(1000, marker_positions)
  MiniTest.expect.equality("marker2", called_with)

  vim.api.nvim_win_is_valid = original_win_is_valid
  vim.api.nvim_win_get_cursor = original_win_get_cursor
  markers.delete_marker = original_delete
  drawer.refresh_current_drawer = original_refresh
end

T["delete functionality / should handle delete failure gracefully"] = function()
  local drawer = require "marker-groups.ui.drawer"
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
    return { success = false, error = "fail" }
  end

  MiniTest.expect.no_error(function()
    drawer.delete_current_marker(1000, marker_positions)
  end)

  vim.api.nvim_win_is_valid = original_win_is_valid
  vim.api.nvim_win_get_cursor = original_win_get_cursor
  markers.delete_marker = original_delete
end

-- annotation display handling
T["annotation display handling / should handle long annotation display"] = function()
  local config = require "marker-groups.config"
  local max_display = config.get_value("max_annotation_display", 50)
  expect_type(max_display, "number")
  expect_truthy(max_display > 0)
end

T["annotation display handling / integration"] = function()
  local long_annotation = string.rep("a", 80)
  expect_truthy(#long_annotation > 50)
  expect_truthy(#long_annotation <= 500)

  local config = require "marker-groups.config"
  local max_display = config.get_value("max_annotation_display", 50)
  local display = long_annotation
  if #display > max_display then
    display = display:sub(1, max_display - 3) .. "..."
  end
  expect_truthy(#display <= max_display + 3)
  MiniTest.expect.equality(display:sub(-3), "...")
end

return T
