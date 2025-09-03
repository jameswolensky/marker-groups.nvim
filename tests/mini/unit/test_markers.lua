local MiniTest = require "mini.test"

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      package.loaded["marker-groups"] = nil
      package.loaded["marker-groups.markers"] = nil
      package.loaded["marker-groups.state"] = nil
      package.loaded["marker-groups.config"] = nil

      local mg = require "marker-groups"
      mg.setup {
        data_dir = vim.fn.tempname() .. "_marker_groups_test",
        log_level = "debug",
        keymaps = { enabled = false },
      }

      local config = require "marker-groups.config"
      require("marker-groups.state").initialize(config.get())

      _G.__mg_created_bufs = {}
    end,

    post_case = function()
      if _G.__mg_created_bufs then
        for _, b in ipairs(_G.__mg_created_bufs) do
          if b and vim.api.nvim_buf_is_valid(b) then
            pcall(vim.api.nvim_buf_delete, b, { force = true })
          end
        end
      end
      _G.__mg_created_bufs = nil
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

local expect_matches = MiniTest.new_expectation("matches", function(str, pat)
  return type(str) == "string" and string.find(str, pat) ~= nil
end, function(str, pat)
  return string.format("Pattern %s not in %s", vim.inspect(pat), vim.inspect(str))
end)

local function create_scratch(lines, prefix)
  local buf = vim.api.nvim_create_buf(false, true)
  lines = lines or { "Line 1" }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local temp_file = string.format("/tmp/%s-%d.lua", prefix or "mg-test", math.random(1000, 9999))
  vim.api.nvim_buf_set_name(buf, temp_file)
  vim.api.nvim_set_current_buf(buf)
  table.insert(_G.__mg_created_bufs, buf)
  return buf, temp_file
end

T["marker creation with validation / should validate annotations when adding markers"] = function()
  local markers = require "marker-groups.markers"
  create_scratch({ "Test line" }, "marker-validation")
  local long_annotation = string.rep("a", 101)
  local result = markers.add_marker(long_annotation)
  expect_falsy(result.success)
  expect_matches(result.error or "", "cannot exceed 100 characters")
end

T["marker creation with validation / editing markers rejects line breaks"] = function()
  local markers = require "marker-groups.markers"
  local state = require "marker-groups.state"
  create_scratch({ "Test line" }, "marker-edit")

  local valid_result = markers.add_marker "Valid annotation"
  expect_truthy(valid_result.success)

  local group = state.get_group "default"
  local marker_id = group.markers[1].id
  local multi = "Line 1\nLine 2"
  local edit_result = markers.edit_marker(marker_id, multi)
  MiniTest.add_note("edit_result.error=" .. tostring(edit_result and edit_result.error))
  expect_falsy(edit_result.success)
  expect_matches(edit_result.error or "", "line breaks")

  local updated = state.get_group "default"
  MiniTest.expect.equality(updated.markers[1].annotation, "Valid annotation")
end

T["marker range operations / should handle adding range markers"] = function()
  local markers = require "marker-groups.markers"
  local state = require "marker-groups.state"
  create_scratch({ "Line 1", "Line 2", "Line 3" }, "marker-range")
  local result = markers.add_marker_range(1, 3, "Multi-line marker")
  expect_truthy(result.success)

  local group = state.get_group "default"
  MiniTest.expect.equality(1, #group.markers)
  MiniTest.expect.equality(1, group.markers[1].start_line)
  MiniTest.expect.equality(3, group.markers[1].end_line)
end

T["marker range operations / should validate range marker annotations"] = function()
  local markers = require "marker-groups.markers"
  create_scratch({ "Line 1", "Line 2" }, "marker-range-long")
  local long_annotation = string.rep("a", 101)
  local result = markers.add_marker_range(1, 2, long_annotation)
  expect_falsy(result.success)
  expect_matches(result.error or "", "cannot exceed 100 characters")
end

T["marker range operations / single-line inside multi-line in same group is not allowed"] = function()
  local markers = require "marker-groups.markers"
  local state = require "marker-groups.state"
  local buf = create_scratch({ "A", "B", "C", "D", "E" }, "marker-overlap")

  local res1 = markers.add_marker_range(1, 3, "multi-line select annotation test")
  expect_truthy(res1.success)

  local res2 = markers.add_marker "single-line annotation test"
  expect_falsy(res2.success)
  expect_matches(res2.error or "", "overlap")

  vim.api.nvim_win_set_cursor(0, { 4, 0 })
  local res3 = markers.add_marker "outside-range"
  expect_truthy(res3.success)
  local group = state.get_group "default"
  MiniTest.expect.equality(2, #group.markers)

  vim.api.nvim_win_set_cursor(0, { 5, 0 })
  local res4 = markers.add_marker "fifth-line"
  expect_truthy(res4.success)
end

T["marker utility functions / should have update/clear/get functions"] = function()
  local markers = require "marker-groups.markers"
  expect_type(markers.update_buffer_markers, "function")
  expect_type(markers.clear_buffer_markers, "function")
  expect_type(markers.get_buffer_markers, "function")
end

T["marker deletion and recreation / allow deleting and recreating multi-line markers"] = function()
  local markers = require "marker-groups.markers"
  local state = require "marker-groups.state"
  create_scratch({ "Line 1", "Line 2", "Line 3" }, "marker-del-recreate")

  local result = markers.add_marker_range(1, 3, "Multi-line marker")
  expect_truthy(result.success)

  local group = state.get_group "default"
  MiniTest.expect.equality(1, #group.markers)
  local marker_id = group.markers[1].id

  local delete_result = markers.delete_marker(marker_id)
  expect_truthy(delete_result.success)

  local updated_group = state.get_group "default"
  MiniTest.expect.equality(0, #updated_group.markers)

  local recreate_result = markers.add_marker_range(1, 3, "Multi-line marker")
  expect_truthy(recreate_result.success)

  local final_group = state.get_group "default"
  MiniTest.expect.equality(1, #final_group.markers)
end

T["validation integration / validate annotations when adding markers via markers module"] = function()
  local markers = require "marker-groups.markers"
  create_scratch({ "Test line" }, "marker-integration")
  local long_annotation = string.rep("a", 101)
  local result = markers.add_marker(long_annotation)
  expect_falsy(result.success)
  expect_matches(result.error or "", "cannot exceed 100 characters")
end

T["validation integration / editing via module rejects line breaks"] = function()
  local markers = require "marker-groups.markers"
  create_scratch({ "Test line" }, "marker-integration-lines")

  local valid_result = markers.add_marker "Valid annotation"
  expect_truthy(valid_result.success)

  local state = require "marker-groups.state"
  local group = state.get_group "default"
  local marker_id = group.markers[1].id

  local multi = "Line 1\nLine 2"
  local edit_result = markers.edit_marker(marker_id, multi)
  MiniTest.add_note("edit_result.error=" .. tostring(edit_result and edit_result.error))
  expect_falsy(edit_result.success)
  expect_matches(edit_result.error or "", "line breaks")
end

return T
