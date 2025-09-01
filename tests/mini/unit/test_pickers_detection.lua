local MiniTest = require "mini.test"

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      package.loaded["marker-groups.pickers"] = nil
    end,
  },
}

T["module exposes setup() and get_status()"] = function()
  local ok, pickers = pcall(require, "marker-groups.pickers")
  MiniTest.expect.equality(true, ok)
  MiniTest.expect.equality("function", type(pickers.setup))
  MiniTest.expect.equality("function", type(pickers.get_status))
end

T["get_status returns expected shape after setup"] = function()
  local pickers = require "marker-groups.pickers"
  pickers.setup { picker = "auto" }
  local status = pickers.get_status()

  MiniTest.expect.equality("table", type(status))
  MiniTest.expect.equality("string", type(status.current_backend), "current_backend must be a string")
  MiniTest.expect.equality("table", type(status.available_backends), "available_backends must be a table")
  MiniTest.expect.equality("table", type(status.backends), "backends must be a table")
end

return T
