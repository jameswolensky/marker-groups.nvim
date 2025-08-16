local assert = require "luassert"
local state = require "marker-groups.state"
local config = require "marker-groups.config"

describe("marker-groups state module", function()
  before_each(function()
    require("marker-groups").setup {
      data_dir = "/tmp/marker-groups-test",
      log_level = "debug",
    }

    state.initialize(config.get())
  end)

  describe("initialization", function()
    it("should initialize with default state", function()
      local current_state = state.get_state()

      assert.is_table(current_state)
      assert.is_table(current_state.marker_groups)
      assert.is_string(current_state.active_group)
      assert.are.equal("default", current_state.active_group)
    end)

    it("should have default group", function()
      local groups = state.get_all_groups()

      assert.is_table(groups)
      assert.is_not_nil(groups.default)
      assert.is_table(groups.default.markers)
    end)
  end)

  describe("group management", function()
    it("should get active group", function()
      local active = state.get_active_group()
      assert.is_string(active)
      assert.are.equal("default", active)
    end)

    it("should set active group", function()
      state.add_group "test-group"

      state.set_active_group "test-group"
      local active = state.get_active_group()

      assert.are.equal("test-group", active)
    end)

    it("should add new groups", function()
      local result = state.add_group "new-group"

      assert.is_true(result.success)

      local groups = state.get_all_groups()
      assert.is_not_nil(groups["new-group"])
      assert.is_table(groups["new-group"].markers)
    end)

    it("should not add duplicate groups", function()
      state.add_group "test-group"
      local result = state.add_group "test-group"

      assert.is_false(result.success)
      assert.is_string(result.error)
    end)

    it("should remove groups", function()
      state.add_group "removable-group"
      local result = state.remove_group "removable-group"

      assert.is_true(result.success)

      local groups = state.get_all_groups()
      assert.is_nil(groups["removable-group"])
    end)

    it("should not remove default group", function()
      local result = state.remove_group "default"

      assert.is_false(result.success)
      assert.is_string(result.error)
    end)

    it("should rename groups", function()
      state.add_group "old-name"
      local groups_module = require "marker-groups.groups"
      local result = groups_module.rename_group("old-name", "new-name")

      assert.is_true(result.success)

      local groups = state.get_all_groups()
      assert.is_nil(groups["old-name"])
      assert.is_not_nil(groups["new-name"])
    end)

    it("allows spaces in group names and treats 'group 2' as valid", function()
      local result = state.create_group "group 2"
      assert.is_true(result.success)
      local groups = state.get_all_groups()
      assert.is_not_nil(groups["group 2"])
    end)

    it("renames without delete/recreate (preserves markers and emits events)", function()
      local create = state.create_group "rename-src"
      assert.is_true(create.success)

      local marker_data = {
        buffer_path = "/tmp/rename-test.lua",
        start_line = 1,
        end_line = 1,
        annotation = "keep me",
      }
      local add_res = state.add_marker(marker_data, "rename-src")
      assert.is_true(add_res.success)

      local renamed
      state.subscribe("group_deleted", function()
        error "group_deleted should not fire during rename"
      end)
      state.subscribe("group_created", function()
        error "group_created should not fire during rename"
      end)
      state.subscribe("group_renamed", function(data)
        renamed = data
      end)

      local groups_module = require "marker-groups.groups"
      local result = groups_module.rename_group("rename-src", "rename-dst")
      assert.is_true(result.success)

      local groups_after = state.get_all_groups()
      assert.is_nil(groups_after["rename-src"])
      assert.is_not_nil(groups_after["rename-dst"])
      assert.are.equal(1, #groups_after["rename-dst"].markers)
      assert.is_truthy(renamed)
      assert.are.equal("rename-src", renamed.old_name)
      assert.are.equal("rename-dst", renamed.new_name)
    end)
  end)

  describe("marker management", function()
    local test_marker

    before_each(function()
      test_marker = {
        buffer_path = "/test/file.lua",
        start_line = 10,
        end_line = 10,
        annotation = "Test marker",
        timestamp = os.time(),
      }
    end)

    it("should add markers to active group", function()
      local result = state.add_marker(test_marker)

      assert.is_true(result.success)

      local group = state.get_group "default"
      assert.are.equal(1, #group.markers)
      assert.are.equal("Test marker", group.markers[1].annotation)
    end)

    it("prevents overlapping markers in the same group and file", function()
      local test_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "A", "B", "C", "D" })
      local temp_file = "/tmp/test-overlap-" .. math.random(1000, 9999) .. ".lua"
      vim.api.nvim_buf_set_name(test_buf, temp_file)

      local first = state.add_marker { buffer_path = temp_file, start_line = 2, end_line = 4, annotation = "first" }
      assert.is_true(first.success)

      local overlap = state.add_marker { buffer_path = temp_file, start_line = 3, end_line = 3, annotation = "second" }
      assert.is_false(overlap.success)
      assert.matches("overlaps", overlap.error)

      vim.api.nvim_buf_delete(test_buf, { force = true })
    end)

    it("should add markers to specific group", function()
      state.add_group "target-group"
      local result = state.add_marker(test_marker, "target-group")

      assert.is_true(result.success)

      local group = state.get_group "target-group"
      assert.are.equal(1, #group.markers)
    end)

    it("should not add invalid markers", function()
      local invalid_marker = { annotation = "Missing required fields" }
      local result = state.add_marker(invalid_marker)

      assert.is_false(result.success)
      assert.is_string(result.error)
    end)

    it("should remove markers", function()
      state.add_marker(test_marker)
      local group = state.get_group "default"
      local marker_id = group.markers[1].id

      local result = state.remove_marker(marker_id)

      assert.is_true(result.success)

      local updated_group = state.get_group "default"
      assert.are.equal(0, #updated_group.markers)
    end)

    it("should update markers", function()
      state.add_marker(test_marker)
      local group = state.get_group "default"
      local marker_id = group.markers[1].id

      local updated_marker = {
        id = marker_id,
        buffer_path = "/test/file.lua",
        start_line = 10,
        end_line = 10,
        annotation = "Updated annotation",
        timestamp = os.time(),
      }

      local result = state.update_marker(updated_marker)

      assert.is_true(result.success)

      local updated_group = state.get_group "default"
      assert.are.equal("Updated annotation", updated_group.markers[1].annotation)
    end)
  end)

  describe("event system", function()
    it("should trigger events on state changes", function()
      local event_triggered = false
      local event_data = nil

      state.subscribe("group_added", function(data)
        event_triggered = true
        event_data = data
      end)

      state.add_group "event-test-group"

      assert.is_true(event_triggered)
      assert.is_table(event_data)
      assert.are.equal("event-test-group", event_data.group_name)
    end)

    it("should unsubscribe from events", function()
      local event_count = 0

      local unsubscribe = state.subscribe("group_added", function()
        event_count = event_count + 1
      end)

      state.add_group "test1"
      assert.are.equal(1, event_count)

      unsubscribe()
      state.add_group "test2"
      assert.are.equal(1, event_count)
    end)
  end)

  describe("state validation", function()
    it("should validate state structure", function()
      local current_state = state.get_state()

      assert.is_table(current_state.marker_groups)
      assert.is_string(current_state.active_group)
      assert.is_number(current_state.version)
    end)

    it("should validate group structure", function()
      local groups = state.get_all_groups()

      for group_name, group_data in pairs(groups) do
        assert.is_string(group_name)
        assert.is_table(group_data)
        assert.is_table(group_data.markers)
        assert.is_number(group_data.created_at)
      end
    end)
  end)

  local test_markers = {}
  local test_buf

  before_each(function()
    test_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "Line 1", "Line 2", "Line 3", "Line 4", "Line 5" })

    local temp_file = "/tmp/test-state-reorder-" .. math.random(1000, 9999) .. ".lua"
    vim.api.nvim_buf_set_name(test_buf, temp_file)

    test_markers = {}
    for i = 1, 5 do
      local marker_data = {
        buffer_path = temp_file,
        start_line = i,
        end_line = i,
        annotation = "Marker " .. i,
      }

      local result = state.add_marker(marker_data)
      assert.is_true(result.success)
      table.insert(test_markers, result.value.id)
    end
  end)

  after_each(function()
    if test_buf and vim.api.nvim_buf_is_valid(test_buf) then
      vim.api.nvim_buf_delete(test_buf, { force = true })
    end
  end)

  describe("core functionality verification", function()
    it("can delete multi-line marker and immediately recreate it", function()
      local test_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "Line 1", "Line 2", "Line 3" })

      local temp_file = "/tmp/test-state-multiline-" .. math.random(1000, 9999) .. ".lua"
      vim.api.nvim_buf_set_name(test_buf, temp_file)

      local marker_data = {
        buffer_path = temp_file,
        start_line = 1,
        end_line = 3,
        annotation = "Multi-line marker",
      }

      local add_result = state.add_marker(marker_data)
      assert.is_true(add_result.success)

      local group = state.get_group "default"
      assert.are.equal(1, #group.markers)
      local marker_id = group.markers[1].id

      local delete_result = state.remove_marker(marker_id)
      assert.is_true(delete_result.success)

      local updated_group = state.get_group "default"
      assert.are.equal(0, #updated_group.markers)

      local recreate_result = state.add_marker(marker_data)
      assert.is_true(recreate_result.success)

      local final_group = state.get_group "default"
      assert.are.equal(1, #final_group.markers)

      vim.api.nvim_buf_delete(test_buf, { force = true })
    end)

    it("can add marker to same line number/range but different marker group", function()
      local test_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "Test line" })

      local temp_file = "/tmp/test-state-sameline-" .. math.random(1000, 9999) .. ".lua"
      vim.api.nvim_buf_set_name(test_buf, temp_file)

      local group_result = state.create_group "second-group"
      assert.is_true(group_result.success)

      local marker_data = {
        buffer_path = temp_file,
        start_line = 1,
        end_line = 1,
        annotation = "First marker",
      }

      local first_result = state.add_marker(marker_data)
      assert.is_true(first_result.success)

      marker_data.annotation = "Second marker"
      local second_result = state.add_marker(marker_data, "second-group")
      assert.is_true(second_result.success)

      local default_group = state.get_group "default"
      local second_group = state.get_group "second-group"

      assert.are.equal(1, #default_group.markers)
      assert.are.equal(1, #second_group.markers)
      assert.are.equal("First marker", default_group.markers[1].annotation)
      assert.are.equal("Second marker", second_group.markers[1].annotation)

      vim.api.nvim_buf_delete(test_buf, { force = true })
    end)

    it("default marker group can never be deleted", function()
      local delete_result = state.delete_group "default"

      assert.is_false(delete_result.success)
      assert.matches("Cannot delete the default group", delete_result.error)

      local group = state.get_group "default"
      assert.is_not_nil(group)
    end)

    it("can delete all markers in a marker group and marker group persists", function()
      local group_result = state.create_group "test-group"
      assert.is_true(group_result.success)

      local test_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "Test line" })

      local temp_file = "/tmp/test-state-deleteall-" .. math.random(1000, 9999) .. ".lua"
      vim.api.nvim_buf_set_name(test_buf, temp_file)

      for i = 1, 3 do
        local marker_data = {
          buffer_path = temp_file,
          start_line = 1,
          end_line = 1,
          annotation = "Marker " .. i,
        }

        local add_result = state.add_marker(marker_data, "test-group")
        assert.is_true(add_result.success)
      end

      local group = state.get_group "test-group"
      assert.are.equal(3, #group.markers)

      for _, marker in ipairs(group.markers) do
        local delete_result = state.remove_marker(marker.id)
        assert.is_true(delete_result.success)
      end

      local final_group = state.get_group "test-group"
      assert.is_not_nil(final_group)
      assert.are.equal(0, #final_group.markers)

      vim.api.nvim_buf_delete(test_buf, { force = true })
    end)
  end)
end)
