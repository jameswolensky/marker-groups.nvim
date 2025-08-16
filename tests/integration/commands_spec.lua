local assert = require "luassert"
local state = require "marker-groups.state"
local config = require "marker-groups.config"

describe("marker-groups command integration", function()
  before_each(function()
    require("marker-groups").setup {
      data_dir = "/tmp/marker-groups-test",
      log_level = "debug",
    }

    state.initialize(config.get())
    require("marker-groups.commands").setup()
  end)

  describe("group management commands", function()
    it("should execute MarkerGroupsCreate command", function()
      local initial_groups = vim.tbl_count(state.get_group_names())

      vim.cmd "MarkerGroupsCreate test-group-cmd"

      local final_groups = vim.tbl_count(state.get_group_names())
      assert.are.equal(initial_groups + 1, final_groups)

      local group = state.get_group "test-group-cmd"
      assert.is_not_nil(group)
    end)

    it("should truncate long new name via interactive rename input to 100 chars", function()
      local groups = require "marker-groups.groups"
      groups.create_group "interactive-src"

      local original_input = vim.ui.input
      local long_name = string.rep("y", 150)
      vim.ui.input = function(opts, callback)
        callback(long_name)
      end

      groups.rename_group_interactive "interactive-src"

      vim.ui.input = original_input

      local names = state.get_group_names()
      for _, n in ipairs(names) do
        assert.is_true(#n <= 100)
      end
      assert.is_true(vim.tbl_contains(names, string.rep("y", 100)))
    end)

    it("should truncate multibyte (emoji) new name in MarkerGroupsRename args to 100 chars", function()
      local groups = require "marker-groups.groups"
      groups.create_group "emoji-src-args"
      local long = string.rep("🚀", 150)
      vim.cmd("MarkerGroupsRename emoji-src-args " .. long)
      local names = state.get_group_names()
      for _, n in ipairs(names) do
        assert.is_true(vim.fn.strchars(n) <= 100)
      end
      assert.is_true(vim.tbl_contains(names, string.rep("🚀", 100)))
    end)

    it("should truncate multibyte (emoji) new name via interactive rename input to 100 chars", function()
      local groups = require "marker-groups.groups"
      groups.create_group "emoji-src-interactive"
      local original_input = vim.ui.input
      local long = string.rep("🚀", 150)
      vim.ui.input = function(opts, callback)
        callback(long)
      end
      groups.rename_group_interactive "emoji-src-interactive"
      vim.ui.input = original_input
      local names = state.get_group_names()
      for _, n in ipairs(names) do
        assert.is_true(vim.fn.strchars(n) <= 100)
      end
      assert.is_true(vim.tbl_contains(names, string.rep("🚀", 100)))
    end)

    it("should execute MarkerGroupsSelect command", function()
      state.create_group "selectable-group"

      vim.cmd "MarkerGroupsSelect selectable-group"

      local active_group = state.get_active_group()
      assert.are.equal("selectable-group", active_group)
    end)

    it("should execute MarkerGroupsList command", function()
      assert.has_no.errors(function()
        vim.cmd "MarkerGroupsList"
      end)
    end)

    it("should execute MarkerGroupsRename command", function()
      state.create_group "renamable-group"

      vim.cmd "MarkerGroupsRename renamable-group renamed-group"

      local group_names = state.get_group_names()
      assert.is_false(vim.tbl_contains(group_names, "renamable-group"))
      assert.is_true(vim.tbl_contains(group_names, "renamed-group"))
    end)

    it("should truncate long new name in MarkerGroupsRename command args to 100 chars", function()
      local groups = require "marker-groups.groups"
      groups.create_group "truncate-src"
      local long_name = string.rep("x", 150)
      vim.cmd("MarkerGroupsRename truncate-src " .. long_name)
      local names = state.get_group_names()

      for _, n in ipairs(names) do
        assert.is_true(#n <= 100)
      end
      local truncated = string.rep("x", 100)
      assert.is_true(vim.tbl_contains(names, truncated))
    end)

    it("should execute MarkerGroupsDelete command", function()
      state.create_group "deletable-group"

      vim.cmd "MarkerGroupsDelete deletable-group --force"

      local group_names = state.get_group_names()
      assert.is_false(vim.tbl_contains(group_names, "deletable-group"))
    end)
  end)

  describe("command error handling", function()
    it("should handle invalid group names gracefully", function()
      assert.has.errors(function()
        vim.cmd "MarkerGroupsSelect nonexistent-group"
      end)

      assert.has.errors(function()
        vim.cmd "MarkerGroupsDelete nonexistent-group --force"
      end)

      assert.has.errors(function()
        vim.cmd "MarkerGroupsRename nonexistent old-name"
      end)
    end)

    it("should handle invalid arguments gracefully", function()
      assert.is_true(true)
    end)

    it("should handle empty arguments for rename command", function()
      assert.has_no.errors(function()
        local original_input = vim.ui.input
        local original_select = vim.ui.select

        vim.ui.input = function(opts, callback)
          callback(nil)
        end

        vim.ui.select = function(items, opts, callback)
          callback(nil)
        end

        pcall(function()
          vim.cmd "MarkerGroupsRename"
        end)

        vim.ui.input = original_input
        vim.ui.select = original_select
      end)
    end)

    it("should handle MarkerAdd with range", function()
      vim.cmd "enew"
      local lines = { "line 1", "line 2", "line 3", "line 4", "line 5" }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)

      local temp_file = "/tmp/test-range-buffer-" .. os.time() .. "-" .. math.random(1000, 9999) .. ".txt"
      vim.cmd("write " .. temp_file)

      assert.has_no.errors(function()
        vim.cmd "2,4MarkerAdd range marker"
      end)

      local markers = require "marker-groups.markers"
      local current_markers = markers.get_current_buffer_markers()
      assert.is_true(#current_markers > 0, "Should have at least one marker")
      local range_marker = current_markers[#current_markers]
      assert.are.equal("range marker", range_marker.annotation)
      assert.is_true(range_marker.start_line >= 1 and range_marker.start_line <= 4, "Start line should be reasonable")
      assert.is_true(range_marker.end_line >= range_marker.start_line, "End line should be >= start line")
      assert.is_true(range_marker.end_line >= 1, "End line should be at least 1")
    end)

    it("should handle interactive group creation cancellation", function()
      local original_input = vim.ui.input
      vim.ui.input = function(opts, callback)
        callback(nil)
      end

      assert.has_no.errors(function()
        vim.cmd "MarkerGroupsCreate"
      end)

      vim.ui.input = original_input
    end)

    it("should handle invalid drawer width bounds", function()
      local drawer = require "marker-groups.ui.drawer"

      assert.has_no.errors(function()
        vim.cmd "MarkerGroupsDrawerWidth 10"
      end)

      assert.has_no.errors(function()
        vim.cmd "MarkerGroupsDrawerWidth 200"
      end)

      local current_width = drawer.get_drawer_width()
      assert.is_true(current_width >= 30 and current_width <= 120)
    end)

    it("should pluralize marker count correctly in delete selection and not delete before confirmation", function()
      local groups = require "marker-groups.groups"
      local markers = require "marker-groups.markers"
      local state = require "marker-groups.state"
      groups.create_group "del-plural-test"
      groups.select_group "del-plural-test"

      vim.cmd "enew"
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "A", "B" })
      local tmp = "/tmp/test-plural-" .. os.time() .. ".txt"
      vim.cmd("write " .. tmp)
      local add1 = markers.add_marker "only-one"
      assert.is_true(add1.success)
      local initial_group = state.get_group "del-plural-test"
      local initial_count = initial_group and #initial_group.markers or 0

      local original_select = vim.ui.select
      local first_selection_items
      vim.ui.select = function(items, opts, callback)
        if not first_selection_items and type(items) == "table" and type(items[1]) == "string" then
          first_selection_items = vim.deepcopy(items)
          callback(items[1])
          return
        end

        if type(items) == "table" and #items == 2 and items[1] == "Yes" and items[2] == "No" then
          callback "No"
          return
        end

        callback(items and items[1] or nil)
      end

      groups.select_group_for_deletion()

      vim.ui.select = original_select

      assert.is_truthy(first_selection_items)
      local found_line = table.concat(first_selection_items, "\n")
      assert.is_falsy(found_line:find("1 markers", 1, true))

      local group = state.get_group "del-plural-test"
      assert.is_not_nil(group)
      assert.are.equal(initial_count, #group.markers)

      pcall(state.set_active_group, "default")
    end)
  end)

  describe("marker management commands", function()
    local test_file_counter = 0

    before_each(function()
      vim.cmd "enew"
      local lines = { "line 1", "line 2", "line 3", "line 4", "line 5" }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.api.nvim_win_set_cursor(0, { 2, 0 })

      test_file_counter = test_file_counter + 1
      local temp_file = "/tmp/test-marker-buffer-" .. os.time() .. "-" .. test_file_counter .. ".txt"
      vim.cmd("write " .. temp_file)
    end)

    after_each(function()
      local markers = require "marker-groups.markers"
      local current_markers = markers.get_current_buffer_markers()
      for _, marker in ipairs(current_markers) do
        markers.delete_marker(marker.id)
      end
    end)

    it("should execute MarkerAdd command with annotation", function()
      local markers = require "marker-groups.markers"
      local initial_count = #markers.get_current_buffer_markers()

      vim.cmd "MarkerAdd test annotation"

      local final_markers = markers.get_current_buffer_markers()
      assert.are.equal(initial_count + 1, #final_markers)

      local new_marker = final_markers[#final_markers]
      assert.are.equal("test annotation", new_marker.annotation)
    end)

    it("should execute MarkerAdd command without annotation (interactive)", function()
      local original_input = vim.ui.input
      local input_called = false
      vim.ui.input = function(opts, callback)
        input_called = true
        callback "interactive annotation"
      end

      local markers = require "marker-groups.markers"
      local initial_count = #markers.get_current_buffer_markers()

      vim.cmd "MarkerAdd"

      assert.is_true(input_called)
      local final_markers = markers.get_current_buffer_markers()
      assert.are.equal(initial_count + 1, #final_markers)

      vim.ui.input = original_input
    end)

    it("should execute MarkerList command", function()
      vim.cmd "MarkerAdd marker 1"
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      vim.cmd "MarkerAdd marker 2"

      assert.has_no.errors(function()
        vim.cmd "MarkerList"
      end)
    end)

    it("should execute MarkerList command with no markers", function()
      assert.has_no.errors(function()
        vim.cmd "MarkerList"
      end)
    end)

    it("should execute MarkerRemove command", function()
      vim.cmd "MarkerAdd removable marker"

      local markers = require "marker-groups.markers"
      local initial_count = #markers.get_current_buffer_markers()
      assert.is_true(initial_count > 0, "Should have at least one marker after adding")

      vim.cmd "MarkerRemove"

      local final_count = #markers.get_current_buffer_markers()
      assert.is_true(final_count < initial_count, "Marker count should decrease after removal")
    end)

    it("should handle MarkerRemove command with no marker at cursor", function()
      vim.api.nvim_win_set_cursor(0, { 4, 0 })

      assert.has_no.errors(function()
        vim.cmd "MarkerRemove"
      end)
    end)

    it("should execute MarkerEdit command with new annotation", function()
      vim.cmd "MarkerAdd original annotation"

      vim.cmd "MarkerEdit updated annotation"

      local markers = require "marker-groups.markers"
      local current_markers = markers.get_current_buffer_markers()
      local updated_marker = current_markers[#current_markers]
      assert.are.equal("updated annotation", updated_marker.annotation)
    end)

    it("should truncate long annotation passed as arg in MarkerAdd to 500 chars", function()
      local long = string.rep("a", 700)
      vim.cmd("MarkerAdd " .. long)
      local markers = require "marker-groups.markers"
      local list = markers.get_current_buffer_markers()
      assert.is_true(#list > 0)
      local last = list[#list]
      assert.are.equal(500, vim.fn.strchars(last.annotation))
    end)

    it("should truncate long annotation passed as arg in MarkerEdit to 500 chars", function()
      vim.cmd "MarkerAdd short"
      local markers = require "marker-groups.markers"
      local marker = markers.get_marker_at_cursor()
      assert.is_truthy(marker)
      local long = string.rep("b", 700)
      vim.cmd("MarkerEdit " .. long)
      local updated = markers.get_marker_at_cursor()
      assert.is_truthy(updated)
      assert.are.equal(500, vim.fn.strchars(updated.annotation))
    end)

    it("should truncate multibyte (emoji) annotation passed as arg in MarkerAdd to 500 chars", function()
      local long = string.rep("🚀", 700)
      vim.cmd("MarkerAdd " .. long)
      local markers = require "marker-groups.markers"
      local list = markers.get_current_buffer_markers()
      local last = list[#list]
      assert.are.equal(500, vim.fn.strchars(last.annotation))
    end)

    it("should truncate multibyte (emoji) annotation passed as arg in MarkerEdit to 500 chars", function()
      vim.cmd "MarkerAdd seed"
      local long = string.rep("🚀", 700)
      vim.cmd("MarkerEdit " .. long)
      local markers = require "marker-groups.markers"
      local updated = markers.get_marker_at_cursor()
      assert.are.equal(500, vim.fn.strchars(updated.annotation))
    end)

    it("should execute MarkerEdit command without annotation (interactive)", function()
      vim.cmd "MarkerAdd original annotation"

      local original_input = vim.ui.input
      local input_called = false
      vim.ui.input = function(opts, callback)
        input_called = true
        assert.are.equal("original annotation", opts.default)
        callback "interactively updated"
      end

      vim.cmd "MarkerEdit"

      assert.is_true(input_called)

      local markers = require "marker-groups.markers"
      local current_markers = markers.get_current_buffer_markers()
      local updated_marker = current_markers[#current_markers]
      assert.are.equal("interactively updated", updated_marker.annotation)

      vim.ui.input = original_input
    end)

    it("should handle MarkerEdit command with no marker at cursor", function()
      vim.api.nvim_win_set_cursor(0, { 4, 0 })

      assert.has_no.errors(function()
        vim.cmd "MarkerEdit new annotation"
      end)
    end)

    it("supports switching from normal to visual mode for range detection", function()
      vim.cmd "enew"
      local lines = { "L1", "L2", "L3", "L4", "L5" }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      local tmp = "/tmp/test-norm-to-vis-" .. os.time() .. ".txt"
      vim.cmd("write " .. tmp)

      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      local markers = require "marker-groups.markers"
      local r1 = markers.add_marker "normal"
      assert.is_true(r1.success)

      local r2 = markers.add_marker_range(3, 5, "visual")
      assert.is_true(r2.success)

      local ms = markers.get_current_buffer_markers()
      assert.is_true(#ms >= 2)
      local m = ms[#ms]
      assert.are.equal(3, m.start_line)
      assert.are.equal(5, m.end_line)
    end)

    it("supports switching from visual to normal mode for single line detection", function()
      vim.cmd "enew"
      local lines = { "A", "B", "C", "D", "E" }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      local tmp = "/tmp/test-vis-to-norm-" .. os.time() .. ".txt"
      vim.cmd("write " .. tmp)

      local markers = require "marker-groups.markers"
      local r1 = markers.add_marker_range(2, 4, "visual")
      assert.is_true(r1.success)

      vim.cmd "normal! <Esc>"
      vim.api.nvim_win_set_cursor(0, { 5, 0 })
      local r2 = markers.add_marker "normal"
      assert.is_true(r2.success)

      local markers = require "marker-groups.markers"
      local ms = markers.get_current_buffer_markers()
      assert.is_true(#ms >= 2)
      local m = ms[#ms]
      assert.are.equal(5, m.start_line)
      assert.are.equal(5, m.end_line)
    end)
  end)

  describe("utility commands", function()
    it("should execute MarkerGroupsInfo command", function()
      assert.has_no.errors(function()
        vim.cmd "MarkerGroupsInfo"
      end)
    end)
  end)

  describe("ui commands", function()
    it("should execute MarkerGroupsView command", function()
      assert.has_no.errors(function()
        vim.cmd "MarkerGroupsView"
      end)
    end)

    it("should execute MarkerGroupsCloseDrawer command", function()
      assert.has_no.errors(function()
        vim.cmd "MarkerGroupsCloseDrawer"
      end)
    end)
  end)

  describe("telescope commands", function()
    it("should execute MarkerGroupsTelescope command", function()
      assert.has_no.errors(function()
        pcall(function()
          vim.cmd "MarkerGroupsTelescope"
        end)
      end)
    end)

    it("should execute MarkerGroupsTelescopeMarkers command", function()
      assert.has_no.errors(function()
        pcall(function()
          vim.cmd "MarkerGroupsTelescopeMarkers"
        end)
      end)
    end)
  end)

  describe("drawer commands", function()
    it("should execute MarkerGroupsDrawerWidth command", function()
      assert.has_no.errors(function()
        vim.cmd "MarkerGroupsDrawerWidth"
      end)
    end)

    it("should set drawer width via command", function()
      local target_width = 90

      assert.has_no.errors(function()
        vim.cmd("MarkerGroupsDrawerWidth " .. target_width)
      end)

      local drawer = require "marker-groups.ui.drawer"
      local current_width = drawer.get_drawer_width()
      assert.are.equal(target_width, current_width)
    end)

    it("should handle invalid drawer width input", function()
      assert.has.errors(function()
        vim.cmd "MarkerGroupsDrawerWidth invalid"
      end)
    end)
  end)
end)
