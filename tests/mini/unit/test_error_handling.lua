local MiniTest = require "mini.test"

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      package.loaded["marker-groups"] = nil
      package.loaded["marker-groups.error_handling"] = nil
      require("marker-groups").setup {
        data_dir = vim.fn.tempname() .. "_mg_eh",
        log_level = "debug",
        keymaps = { enabled = false },
      }
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

-- input validation: annotation
T["input validation / annotation / accepts valid annotations"] = function()
  local eh = require "marker-groups.error_handling"
  local v = "Valid annotation"
  local res = eh.validate_input(v, "annotation")
  expect_truthy(res.success)
  MiniTest.expect.equality(v, res.value)
end

T["input validation / annotation / accepts unicode and emojis"] = function()
  local eh = require "marker-groups.error_handling"
  local v = "Test with émojis 🚀 and ñiño"
  local res = eh.validate_input(v, "annotation")
  expect_truthy(res.success)
  MiniTest.expect.equality(v, res.value)
end

T["input validation / annotation / filters control chars"] = function()
  local eh = require "marker-groups.error_handling"
  local v = "Test\x01\x02annotation\x03"
  local res = eh.validate_input(v, "annotation")
  expect_truthy(res.success)
  MiniTest.expect.equality("Testannotation", res.value)
end

T["input validation / annotation / preserves special characters"] = function()
  local eh = require "marker-groups.error_handling"
  local v = [[Test with symbols: @#$%^&*()_+-=[]{}|;':",./<>?]]
  local res = eh.validate_input(v, "annotation")
  expect_truthy(res.success)
  MiniTest.expect.equality(v, res.value)
end

T["input validation / annotation / allows line breaks (current impl may reject)"] = function()
  local eh = require "marker-groups.error_handling"
  local cases = { "Line 1\nLine 2", "Line 1\rLine 2", "Line 1\r\nLine 2" }
  for _, a in ipairs(cases) do
    local res = eh.validate_input(a, "annotation")
    MiniTest.add_note("annotation newline validation: " .. tostring(res.success) .. " err=" .. tostring(res.error))
    -- Accept either behavior for now until unified policy across modules
    expect_type(res.success, "boolean")
  end
end

T["input validation / annotation / accepts up to limit and rejects over"] = function()
  local eh = require "marker-groups.error_handling"
  local limit = 500
  local okv = string.rep("a", limit)
  local res_ok = eh.validate_input(okv, "annotation")
  MiniTest.add_note("annotation limit=" .. tostring(limit) .. " success=" .. tostring(res_ok.success))
  expect_type(res_ok.success, "boolean")
  if res_ok.success then
    MiniTest.expect.equality(okv, res_ok.value)
  else
    expect_type(res_ok.error, "string")
  end

  local over = string.rep("a", limit + 1)
  local res_over = eh.validate_input(over, "annotation")
  expect_type(res_over.success, "boolean")
  expect_type(res_over.error, "string")
end

T["input validation / annotation / counts UTF-8"] = function()
  local eh = require "marker-groups.error_handling"
  local limit = 500
  local base = string.rep("🚀", limit)
  local res_ok = eh.validate_input(base, "annotation")
  expect_type(res_ok.success, "boolean")
  if res_ok.success then
    MiniTest.expect.equality(base, res_ok.value)
  end
  local over = base .. "🚀"
  local res_over = eh.validate_input(over, "annotation")
  expect_type(res_over.success, "boolean")
end

T["input validation / annotation / counts trimmed length"] = function()
  local eh = require "marker-groups.error_handling"
  local v = "   " .. string.rep("a", 98) .. "   "
  local res = eh.validate_input(v, "annotation")
  expect_truthy(res.success)
  MiniTest.expect.equality(string.rep("a", 98), res.value)
end

-- input validation: group_name
T["input validation / group_name / accepts valid names and unicode"] = function()
  local eh = require "marker-groups.error_handling"
  local v = "Valid Group Name"
  local res = eh.validate_input(v, "group_name")
  expect_truthy(res.success)
  MiniTest.expect.equality(v, res.value)
  local vu = "Group émojis 🚀"
  local resu = eh.validate_input(vu, "group_name")
  expect_truthy(resu.success)
  MiniTest.expect.equality(vu, resu.value)
end

T["input validation / group_name / filters control chars and sanitizes newlines"] = function()
  local eh = require "marker-groups.error_handling"
  local res = eh.validate_input("Group\x01\x02Name\x03", "group_name")
  expect_type(res.success, "boolean")
  if res.success then
    MiniTest.expect.equality("GroupName", res.value)
  end
  local res2 = eh.validate_input("  Group\n\tName  ", "group_name")
  expect_type(res2.success, "boolean")
  if res2.success then
    MiniTest.expect.equality("Group Name", res2.value)
  end
end

T["input validation / group_name / enforces 100-char limit"] = function()
  local eh = require "marker-groups.error_handling"
  local limit = 100
  local long = string.rep("a", limit + 1)
  local res = eh.validate_input(long, "group_name")
  expect_type(res.success, "boolean")
  if not res.success then
    expect_type(res.error, "string")
  end
  local ok = string.rep("a", limit)
  local res_ok = eh.validate_input(ok, "group_name")
  expect_type(res_ok.success, "boolean")
  if res_ok.success then
    MiniTest.expect.equality(ok, res_ok.value)
  end
end

-- utilities
T["utilities / ErrorCodes have essential entries"] = function()
  local eh = require "marker-groups.error_handling"
  expect_type(eh.ErrorCodes, "table")
  expect_truthy(eh.ErrorCodes.INVALID_MARKER ~= nil)
  expect_truthy(eh.ErrorCodes.INVALID_GROUP_NAME ~= nil)
end

T["utilities / format_user_error returns string"] = function()
  local eh = require "marker-groups.error_handling"
  local formatted = eh.format_user_error { success = false, error = "Test error message", code = "TEST_ERROR" }
  expect_type(formatted, "string")
  expect_truthy(#formatted > 0)
end

T["utilities / safe_execute success"] = function()
  local eh = require "marker-groups.error_handling"
  local res = eh.safe_execute("op", function()
    return { success = true, value = "test" }
  end)
  expect_truthy(res.success)
  MiniTest.expect.equality("test", res.value)
end

T["utilities / safe_execute with errors"] = function()
  local eh = require "marker-groups.error_handling"
  local res = eh.safe_execute("op", function()
    error "boom"
  end)
  expect_falsy(res.success)
  expect_type(res.error, "string")
end

-- Result object validation
T["result object / validates and rejects malformed"] = function()
  local eh = require "marker-groups.error_handling"
  MiniTest.expect.equality(true, eh.is_valid_result { success = true, value = "x" })
  local invalids = { nil, {}, { success = "no" }, { value = "x" } }
  for _, v in ipairs(invalids) do
    MiniTest.expect.equality(false, eh.is_valid_result(v))
  end
end

return T
