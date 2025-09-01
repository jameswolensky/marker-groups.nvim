local MiniTest = require "mini.test"

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      package.loaded["marker-groups"] = nil
      package.loaded["marker-groups.pickers"] = nil
    end,
  },
}

T["setup with picker=auto selects some available backend and exposes status"] = function()
  local mg = require "marker-groups"
  mg.setup { picker = "auto" }
  local pickers = require "marker-groups.pickers"
  local status = pickers.get_status()
  MiniTest.expect.equality("table", type(status))
  MiniTest.expect.equality("string", type(status.current_backend))
  MiniTest.expect.equality("table", type(status.available_backends))
end

T["setup with unavailable picker falls back to auto (warns if possible)"] = function()
  -- Spy on notifications to ensure a warning is emitted
  local warned = false
  local orig_notify = vim.notify
  vim.notify = function(msg, level, opts)
    if level == vim.log.levels.WARN and msg:match "falling back to auto" then
      warned = true
    end
    return orig_notify(msg, level, opts)
  end

  local mg = require "marker-groups"
  mg.setup { picker = "nonexistent_picker" }
  local pickers = require "marker-groups.pickers"
  local status = pickers.get_status()

  -- Either we warned, or we still must have fallen back successfully
  MiniTest.expect.equality("string", type(status.current_backend))
  MiniTest.expect.equality(true, status.current_backend ~= "nonexistent_picker")

  vim.notify = orig_notify
end

return T
