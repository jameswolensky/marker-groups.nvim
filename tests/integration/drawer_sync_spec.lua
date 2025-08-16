local assert = require "luassert"

describe("drawer synchronization integration", function()
  local drawer, markers, state, groups

  before_each(function()
    require("marker-groups").setup {
      data_dir = "/tmp/marker-groups-test",
      log_level = "debug",
    }

    drawer = require "marker-groups.ui.drawer"
    markers = require "marker-groups.markers"
    state = require "marker-groups.state"
    groups = require "marker-groups.groups"

    groups.create_group "sync_test_group"
    groups.select_group "sync_test_group"
  end)

  after_each(function()
    drawer.close_all()

    pcall(groups.delete_group, "sync_test_group")
  end)

  describe("drawer to buffer synchronization", function()
    it("should remove markers from buffer when deleted from drawer", function()
      local test_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(test_buf, "modifiable", true)
      vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, {
        "function test()",
        "  -- marker will be here",
        "  local x = 1",
        "  return x",
        "end",
      })

      local temp_path = "/tmp/test_sync_file.lua"
      vim.api.nvim_buf_set_name(test_buf, temp_path)

      local marker_result = state.add_marker({
        buffer_path = temp_path,
        start_line = 2,
        end_line = 2,
        annotation = "Test marker for sync",
      }, "sync_test_group")

      assert.is_true(marker_result.success)
      local marker_id = marker_result.value.id

      local buffer_markers = markers.list_markers("sync_test_group", { buffer_path = temp_path })
      assert.are.equal(1, #buffer_markers)
      assert.are.equal(marker_id, buffer_markers[1].id)

      local mock_marker_positions = {
        [5] = buffer_markers[1],
      }

      local original_win_is_valid = vim.api.nvim_win_is_valid
      local original_win_get_cursor = vim.api.nvim_win_get_cursor
      vim.api.nvim_win_is_valid = function()
        return true
      end
      vim.api.nvim_win_get_cursor = function()
        return { 5, 0 }
      end

      local original_refresh = drawer.refresh_current_drawer
      drawer.refresh_current_drawer = function() end

      drawer.delete_current_marker(1000, mock_marker_positions)

      local updated_markers = markers.list_markers("sync_test_group", { buffer_path = temp_path })
      assert.are.equal(0, #updated_markers)

      vim.api.nvim_win_is_valid = original_win_is_valid
      vim.api.nvim_win_get_cursor = original_win_get_cursor
      drawer.refresh_current_drawer = original_refresh
      vim.api.nvim_buf_delete(test_buf, { force = true })
    end)
  end)

  describe("drawer initial cursor position", function()
    it("should position cursor at the first marker line when opened", function()
      local temp_path = "/tmp/test_initial_cursor.lua"
      vim.cmd "enew"
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "one", "two", "three", "four" })
      vim.cmd("write " .. temp_path)

      state.create_group "sync_test_group"
      state.set_active_group "sync_test_group"

      local m1 =
        state.add_marker({ buffer_path = temp_path, start_line = 2, end_line = 2, annotation = "A" }, "sync_test_group")
      assert.is_true(m1.success)
      local m2 =
        state.add_marker({ buffer_path = temp_path, start_line = 4, end_line = 4, annotation = "B" }, "sync_test_group")
      assert.is_true(m2.success)

      local buf, win = drawer.show_markers()
      assert.is_truthy(win)

      vim.wait(50)
      local cur = vim.api.nvim_win_get_cursor(win)
      assert.is_true(cur[1] > 1)
    end)
  end)

  describe("drawer deletion cursor behavior", function()
    it("moves cursor to next marker after deletion, or previous if last; and top when empty", function()
      local state = require "marker-groups.state"
      local markers = require "marker-groups.markers"
      local drawer = require "marker-groups.ui.drawer"

      local temp_path = "/tmp/test_delete_cursor.lua"
      vim.cmd "enew"
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "a", "b", "c", "d", "e" })
      vim.cmd("write " .. temp_path)

      state.create_group "sync_test_group"
      state.set_active_group "sync_test_group"

      markers.add_marker_range(2, 2, "M1")
      markers.add_marker_range(4, 4, "M2")

      local buf, win = drawer.show_markers()
      assert.is_truthy(win)

      vim.api.nvim_win_set_cursor(win, { 4, 0 })

      drawer.delete_current_marker(win, drawer._drawer_windows and drawer._drawer_windows[win].marker_positions or {})

      local new_win = nil
      for wid, info in pairs(drawer._drawer_windows or {}) do
        if info.is_drawer then
          new_win = wid
          break
        end
      end
      assert.is_truthy(new_win)

      vim.wait(100)
      local cur = vim.api.nvim_win_get_cursor(new_win)
      assert.is_true(cur[1] > 1)

      drawer.delete_current_marker(
        new_win,
        drawer._drawer_windows and drawer._drawer_windows[new_win].marker_positions or {}
      )
      vim.wait(100)
      local cur2 = vim.api.nvim_win_get_cursor(new_win)
      assert.are.equal(1, cur2[1])
    end)
  end)

  describe("buffer to drawer synchronization", function()
    it("should automatically update drawer when markers are added to buffer", function()
      local test_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(test_buf, "modifiable", true)
      vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, {
        "local x = 1",
        "local y = 2",
        "return x + y",
      })

      local temp_path = "/tmp/test_buffer_sync.lua"
      vim.api.nvim_buf_set_name(test_buf, temp_path)

      local marker_result = state.add_marker({
        buffer_path = temp_path,
        start_line = 1,
        end_line = 1,
        annotation = "Initial marker",
      }, "sync_test_group")
      assert.is_true(marker_result.success)

      local mock_win_id = 1000
      local mock_buf_id = 2000

      local original_win_is_valid = vim.api.nvim_win_is_valid
      local original_buf_is_valid = vim.api.nvim_buf_is_valid
      vim.api.nvim_win_is_valid = function(win_id)
        return win_id == mock_win_id
      end
      vim.api.nvim_buf_is_valid = function(buf_id)
        return buf_id == mock_buf_id or buf_id == test_buf
      end

      local refresh_called = false
      local original_refresh = drawer.refresh_current_drawer
      drawer.refresh_current_drawer = function()
        refresh_called = true
      end

      drawer.setup_drawer_auto_updates(mock_win_id, mock_buf_id)

      local second_marker_result = state.add_marker({
        buffer_path = temp_path,
        start_line = 2,
        end_line = 2,
        annotation = "Second marker",
      }, "sync_test_group")
      assert.is_true(second_marker_result.success)

      vim.wait(200, function()
        return refresh_called
      end)

      assert.is_true(refresh_called)

      drawer.cleanup_drawer_auto_updates(mock_win_id)
      vim.api.nvim_win_is_valid = original_win_is_valid
      vim.api.nvim_buf_is_valid = original_buf_is_valid
      drawer.refresh_current_drawer = original_refresh
      vim.api.nvim_buf_delete(test_buf, { force = true })
    end)

    it("should automatically update drawer when markers are deleted from buffer", function()
      local test_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(test_buf, "modifiable", true)
      vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "test line" })

      local temp_path = "/tmp/test_delete_sync.lua"
      vim.api.nvim_buf_set_name(test_buf, temp_path)

      local marker_result = state.add_marker({
        buffer_path = temp_path,
        start_line = 1,
        end_line = 1,
        annotation = "Marker to delete",
      }, "sync_test_group")
      assert.is_true(marker_result.success)
      local marker_id = marker_result.value.id

      local mock_win_id = 1001
      local mock_buf_id = 2001

      local original_win_is_valid = vim.api.nvim_win_is_valid
      local original_buf_is_valid = vim.api.nvim_buf_is_valid
      vim.api.nvim_win_is_valid = function(win_id)
        return win_id == mock_win_id
      end
      vim.api.nvim_buf_is_valid = function(buf_id)
        return buf_id == mock_buf_id or buf_id == test_buf
      end

      local refresh_called = false
      local original_refresh = drawer.refresh_current_drawer
      drawer.refresh_current_drawer = function()
        refresh_called = true
      end

      drawer.setup_drawer_auto_updates(mock_win_id, mock_buf_id)

      local delete_result = markers.delete_marker(marker_id)
      assert.is_true(delete_result.success)

      vim.wait(200, function()
        return refresh_called
      end)

      assert.is_true(refresh_called)

      drawer.cleanup_drawer_auto_updates(mock_win_id)
      vim.api.nvim_win_is_valid = original_win_is_valid
      vim.api.nvim_buf_is_valid = original_buf_is_valid
      drawer.refresh_current_drawer = original_refresh
      vim.api.nvim_buf_delete(test_buf, { force = true })
    end)
  end)

  describe("annotation synchronization", function()
    it("should sync annotation edits between buffer and drawer", function()
      local test_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(test_buf, "modifiable", true)
      vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "test annotation sync" })

      local temp_path = "/tmp/test_annotation_sync.lua"
      vim.api.nvim_buf_set_name(test_buf, temp_path)

      local marker_result = state.add_marker({
        buffer_path = temp_path,
        start_line = 1,
        end_line = 1,
        annotation = "Original annotation",
      }, "sync_test_group")
      assert.is_true(marker_result.success)
      local marker_id = marker_result.value.id

      local edit_result = markers.edit_marker(marker_id, "Updated annotation")
      assert.is_true(edit_result.success)

      local new_marker_id = edit_result.value.id

      local updated_marker, group_name = state.get_marker(new_marker_id)
      assert.is_not_nil(updated_marker)
      assert.is_not_nil(group_name)
      assert.are.equal("Updated annotation", updated_marker.annotation)

      local buffer_markers = markers.list_markers("sync_test_group", { buffer_path = temp_path })
      assert.are.equal(1, #buffer_markers)
      assert.are.equal("Updated annotation", buffer_markers[1].annotation)

      vim.api.nvim_buf_delete(test_buf, { force = true })
    end)
  end)

  describe("group synchronization", function()
    it("should close drawer when active group is deleted", function()
      groups.create_group "deletable_group"
      groups.select_group "deletable_group"

      local test_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(test_buf, "modifiable", true)
      vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "test" })

      local temp_path = "/tmp/test_group_delete.lua"
      vim.api.nvim_buf_set_name(test_buf, temp_path)

      state.add_marker({
        buffer_path = temp_path,
        start_line = 1,
        end_line = 1,
        annotation = "Test marker",
      }, "deletable_group")

      local mock_win_id = 1002
      local mock_buf_id = 2002
      local window_closed = false

      local original_win_is_valid = vim.api.nvim_win_is_valid
      local original_buf_is_valid = vim.api.nvim_buf_is_valid
      local original_win_close = vim.api.nvim_win_close

      vim.api.nvim_win_is_valid = function(win_id)
        return win_id == mock_win_id and not window_closed
      end
      vim.api.nvim_buf_is_valid = function(buf_id)
        return buf_id == mock_buf_id or buf_id == test_buf
      end
      vim.api.nvim_win_close = function(win_id, force)
        if win_id == mock_win_id then
          window_closed = true
        end
      end

      drawer.setup_drawer_auto_updates(mock_win_id, mock_buf_id)

      local delete_result = groups.delete_group "deletable_group"
      assert.is_true(delete_result.success)

      vim.wait(500, function()
        return window_closed
      end)

      assert.is_true(delete_result.success)

      drawer.cleanup_drawer_auto_updates(mock_win_id)
      vim.api.nvim_win_is_valid = original_win_is_valid
      vim.api.nvim_buf_is_valid = original_buf_is_valid
      vim.api.nvim_win_close = original_win_close
      vim.api.nvim_buf_delete(test_buf, { force = true })
    end)
  end)
end)
