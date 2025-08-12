local assert = require "luassert"

describe("marker-groups markers module", function()
  local markers
  local state
  local config

  before_each(function()
    require("marker-groups").setup {
      data_dir = "/tmp/marker-groups-test",
      log_level = "debug",
    }

    markers = require "marker-groups.markers"
    state = require "marker-groups.state"
    config = require "marker-groups.config"

    state.initialize(config.get())
  end)

  describe("marker creation with validation", function()
    local test_buf

    before_each(function()
      test_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "Test line" })

      local temp_file = "/tmp/test-marker-validation-" .. math.random(1000, 9999) .. ".lua"
      vim.api.nvim_buf_set_name(test_buf, temp_file)
      vim.api.nvim_set_current_buf(test_buf)
    end)

    after_each(function()
      if test_buf and vim.api.nvim_buf_is_valid(test_buf) then
        vim.api.nvim_buf_delete(test_buf, { force = true })
      end
    end)

    it("should validate annotations when adding markers", function()
      local long_annotation = string.rep("a", 501)
      local result = markers.add_marker(long_annotation)

      assert.is_false(result.success)
      assert.matches("cannot exceed 500 characters", result.error)
    end)

    it("should allow annotations with line breaks when editing markers", function()
      local valid_result = markers.add_marker "Valid annotation"
      assert.is_true(valid_result.success)

      local group = state.get_group "default"
      local marker_id = group.markers[1].id

      local multi = "Line 1\nLine 2"
      local edit_result = markers.edit_marker(marker_id, multi)

      assert.is_true(edit_result.success)
      local updated = state.get_group "default"
      assert.matches("Line 1", updated.markers[1].annotation)
    end)

    it("should accept valid annotations with unicode", function()
      local unicode_annotation = "Test with émojis 🚀"
      local result = markers.add_marker(unicode_annotation)

      assert.is_true(result.success)

      local group = state.get_group "default"
      assert.are.equal(unicode_annotation, group.markers[1].annotation)
    end)
  end)

  describe("marker range operations", function()
    local test_buf

    before_each(function()
      test_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "Line 1", "Line 2", "Line 3" })

      local temp_file = "/tmp/test-marker-range-" .. math.random(1000, 9999) .. ".lua"
      vim.api.nvim_buf_set_name(test_buf, temp_file)
      vim.api.nvim_set_current_buf(test_buf)
    end)

    after_each(function()
      if test_buf and vim.api.nvim_buf_is_valid(test_buf) then
        vim.api.nvim_buf_delete(test_buf, { force = true })
      end
    end)

    it("should handle adding range markers", function()
      local result = markers.add_marker_range(1, 3, "Multi-line marker")

      assert.is_true(result.success)

      local group = state.get_group "default"
      assert.are.equal(1, #group.markers)
      assert.are.equal(1, group.markers[1].start_line)
      assert.are.equal(3, group.markers[1].end_line)
    end)

    it("should validate range marker annotations", function()
      local long_annotation = string.rep("a", 501)
      local result = markers.add_marker_range(1, 2, long_annotation)

      assert.is_false(result.success)
      assert.matches("cannot exceed 500 characters", result.error)
    end)

    it(
      "should not allow adding a single-line marker that is within an existing multi-line marker in the same group",
      function()
        local res1 = markers.add_marker_range(1, 3, "multi-line select annotation test")
        assert.is_true(res1.success)

        local res2 = markers.add_marker "single-line annotation test"
        assert.is_false(res2.success)
        assert.matches("overlap", res2.error)

        vim.api.nvim_win_set_cursor(0, { 4, 0 })
        local res3 = markers.add_marker "outside-range"
        assert.is_true(res3.success)
        local group = state.get_group "default"
        assert.are.equal(2, #group.markers)

        vim.api.nvim_win_set_cursor(0, { 5, 0 })
        local res4 = markers.add_marker "fifth-line"
        assert.is_true(res4.success)
      end
    )
  end)

  describe("marker utility functions", function()
    it("should have update buffer markers function", function()
      assert.is_function(markers.update_buffer_markers)
    end)

    it("should have clear buffer markers function", function()
      assert.is_function(markers.clear_buffer_markers)
    end)

    it("should have get buffer markers function", function()
      assert.is_function(markers.get_buffer_markers)
    end)
  end)

  describe("marker deletion and recreation", function()
    local test_buf

    before_each(function()
      test_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "Line 1", "Line 2", "Line 3" })

      local temp_file = "/tmp/test-marker-deletion-" .. math.random(1000, 9999) .. ".lua"
      vim.api.nvim_buf_set_name(test_buf, temp_file)
      vim.api.nvim_set_current_buf(test_buf)
    end)

    after_each(function()
      if test_buf and vim.api.nvim_buf_is_valid(test_buf) then
        vim.api.nvim_buf_delete(test_buf, { force = true })
      end
    end)

    it("should allow deleting and recreating multi-line markers", function()
      local result = markers.add_marker_range(1, 3, "Multi-line marker")
      assert.is_true(result.success)

      local group = state.get_group "default"
      assert.are.equal(1, #group.markers)
      local marker_id = group.markers[1].id

      local delete_result = markers.delete_marker(marker_id)
      assert.is_true(delete_result.success)

      local updated_group = state.get_group "default"
      assert.are.equal(0, #updated_group.markers)

      local recreate_result = markers.add_marker_range(1, 3, "Multi-line marker")
      assert.is_true(recreate_result.success)

      local final_group = state.get_group "default"
      assert.are.equal(1, #final_group.markers)
    end)
  end)

  describe("validation integration", function()
    local test_buf

    before_each(function()
      test_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "Test line" })

      local temp_file = "/tmp/test-marker-integration-" .. math.random(1000, 9999) .. ".lua"
      vim.api.nvim_buf_set_name(test_buf, temp_file)
      vim.api.nvim_set_current_buf(test_buf)
    end)

    after_each(function()
      if test_buf and vim.api.nvim_buf_is_valid(test_buf) then
        vim.api.nvim_buf_delete(test_buf, { force = true })
      end
    end)

    it("should validate annotations when adding markers via markers module", function()
      local long_annotation = string.rep("a", 501)
      local result = markers.add_marker(long_annotation)

      assert.is_false(result.success)
      assert.matches("cannot exceed 500 characters", result.error)
    end)

    it("should allow annotations with line breaks via markers module", function()
      local valid_result = markers.add_marker "Valid annotation"
      assert.is_true(valid_result.success)

      local group = state.get_group "default"
      local marker_id = group.markers[1].id

      local multi = "Line 1\nLine 2"
      local edit_result = markers.edit_marker(marker_id, multi)

      assert.is_true(edit_result.success)
    end)
  end)
end)
