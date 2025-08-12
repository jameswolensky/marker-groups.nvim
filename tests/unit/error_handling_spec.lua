local assert = require "luassert"

describe("marker-groups error_handling module", function()
  local error_handling

  before_each(function()
    require("marker-groups").setup {
      data_dir = "/tmp/marker-groups-test",
      log_level = "debug",
    }

    error_handling = require "marker-groups.error_handling"
  end)

  describe("input validation functions", function()
    describe("annotation validation", function()
      it("should accept valid annotations", function()
        local valid_annotation = "Valid annotation"
        local result = error_handling.validate_input(valid_annotation, "annotation")

        assert.is_true(result.success)
        assert.are.equal(valid_annotation, result.value)
      end)

      it("should accept unicode characters and emojis", function()
        local unicode_annotation = "Test with émojis 🚀 and ñiño"
        local result = error_handling.validate_input(unicode_annotation, "annotation")

        assert.is_true(result.success)
        assert.are.equal(unicode_annotation, result.value)
      end)

      it("should filter out control characters", function()
        local annotation_with_control = "Test\x01\x02annotation\x03"
        local result = error_handling.validate_input(annotation_with_control, "annotation")

        assert.is_true(result.success)
        assert.are.equal("Testannotation", result.value)
      end)

      it("should preserve valid special characters", function()
        local annotation = "Test with symbols: @#$%^&*()_+-=[]{}|;':\",./<>?"
        local result = error_handling.validate_input(annotation, "annotation")

        assert.is_true(result.success)
        assert.are.equal(annotation, result.value)
      end)

      it("should allow annotations with line breaks", function()
        local test_cases = {
          "Line 1\nLine 2",
          "Line 1\rLine 2",
          "Line 1\r\nLine 2",
        }

        for _, annotation in ipairs(test_cases) do
          local result = error_handling.validate_input(annotation, "annotation")
          assert.is_true(result.success)
        end
      end)

      it("should accept annotations up to 500 characters", function()
        local annotation_500_chars = string.rep("a", 500)
        local result = error_handling.validate_input(annotation_500_chars, "annotation")

        assert.is_true(result.success)
        assert.are.equal(annotation_500_chars, result.value)
      end)

      it("should reject annotations over 500 characters", function()
        local annotation_501_chars = string.rep("a", 501)
        local result = error_handling.validate_input(annotation_501_chars, "annotation")

        assert.is_false(result.success)
        assert.matches("cannot exceed 500 characters", result.error)
      end)

      it("counts UTF-8 characters (not bytes) when enforcing 500-char limit", function()
        local base = string.rep("🚀", 500)
        local result_ok = error_handling.validate_input(base, "annotation")
        assert.is_true(result_ok.success)
        assert.are.equal(base, result_ok.value)

        local over = base .. "🚀"
        local result_over = error_handling.validate_input(over, "annotation")
        assert.is_false(result_over.success)
        assert.matches("cannot exceed 500 characters", result_over.error)
      end)

      it("should count trimmed length correctly", function()
        local annotation_with_spaces = "   " .. string.rep("a", 98) .. "   "
        local result = error_handling.validate_input(annotation_with_spaces, "annotation")

        assert.is_true(result.success)
        assert.are.equal(string.rep("a", 98), result.value)
      end)
    end)

    describe("group name validation", function()
      it("should accept valid group names", function()
        local valid_group = "Valid Group Name"
        local result = error_handling.validate_input(valid_group, "group_name")

        assert.is_true(result.success)
        assert.are.equal(valid_group, result.value)
      end)

      it("should accept unicode characters and emojis in group names", function()
        local unicode_group = "Group émojis 🚀"
        local result = error_handling.validate_input(unicode_group, "group_name")

        assert.is_true(result.success)
        assert.are.equal(unicode_group, result.value)
      end)

      it("should filter out control characters from group names", function()
        local group_with_control = "Group\x01\x02Name\x03"
        local result = error_handling.validate_input(group_with_control, "group_name")

        assert.is_true(result.success)
        assert.are.equal("GroupName", result.value)
      end)

      it("should sanitize group names with line breaks into a single line", function()
        local group_with_newline = "  Group\n\tName  "
        local result = error_handling.validate_input(group_with_newline, "group_name")

        assert.is_true(result.success)
        assert.are.equal("Group Name", result.value)
      end)

      it("should limit group name length to 100 characters", function()
        local long_group_name = string.rep("a", 101)
        local result = error_handling.validate_input(long_group_name, "group_name")

        assert.is_false(result.success)
        assert.matches("cannot exceed 100 characters", result.error)
      end)

      it("should accept group names up to 100 characters", function()
        local group_name_100_chars = string.rep("a", 100)
        local result = error_handling.validate_input(group_name_100_chars, "group_name")

        assert.is_true(result.success)
        assert.are.equal(group_name_100_chars, result.value)
      end)

      it("counts UTF-8 characters (not bytes) for 100-char group name limit", function()
        local base = string.rep("🚀", 100)
        local result_ok = error_handling.validate_input(base, "group_name")
        assert.is_true(result_ok.success)
        assert.are.equal(base, result_ok.value)

        local over = base .. "🚀"
        local result_over = error_handling.validate_input(over, "group_name")
        assert.is_false(result_over.success)
        assert.matches("cannot exceed 100 characters", result_over.error)
      end)
    end)
  end)

  describe("error handling utilities", function()
    it("should have ErrorCodes defined", function()
      assert.is_table(error_handling.ErrorCodes)
      assert.is_not_nil(error_handling.ErrorCodes.INVALID_MARKER)
      assert.is_not_nil(error_handling.ErrorCodes.INVALID_GROUP_NAME)
    end)

    it("should format user-friendly error messages", function()
      local test_result = {
        success = false,
        error = "Test error message",
        code = "TEST_ERROR",
      }

      local formatted = error_handling.format_user_error(test_result)
      assert.is_string(formatted)
      assert.is_true(#formatted > 0)
    end)

    it("should handle safe execution", function()
      local success_result = error_handling.safe_execute("test operation", function()
        return { success = true, value = "test" }
      end)

      assert.is_true(success_result.success)
      assert.are.equal("test", success_result.value)
    end)

    it("should handle safe execution with errors", function()
      local error_result = error_handling.safe_execute("test operation", function()
        error "Test error"
      end)

      assert.is_false(error_result.success)
      assert.is_string(error_result.error)
    end)
  end)

  describe("Result object validation", function()
    it("should validate valid Result objects", function()
      local valid_result = { success = true, value = "test" }
      local is_valid = error_handling.is_valid_result(valid_result)

      assert.is_true(is_valid)
    end)

    it("should invalidate malformed Result objects", function()
      local invalid_results = {
        nil,
        {},
        { success = "not_boolean" },
        { value = "test" },
      }

      for _, invalid_result in ipairs(invalid_results) do
        local is_valid = error_handling.is_valid_result(invalid_result)
        assert.is_false(is_valid)
      end
    end)
  end)
end)
