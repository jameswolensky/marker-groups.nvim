local MiniTest = require "mini.test"

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      package.loaded["marker-groups"] = nil
      package.loaded["marker-groups.pickers"] = nil
    end,
  },
}

T["setup with invalid picker falls back to vim_ui"] = function()
  local mg = require "marker-groups"
  mg.setup { picker = "nonexistent_picker" }
  local pickers = require "marker-groups.pickers"
  local status = pickers.get_status()
  MiniTest.expect.equality("vim_ui", status.current_backend)
end

return T
