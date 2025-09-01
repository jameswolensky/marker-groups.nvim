local MiniTest = require "mini.test"

local T = MiniTest.new_set {}

T["show_notification calls vim.notify and sets timer"] = function()
  local utils = require "marker-groups.pickers.utils"
  local notified = false
  local defer_called = false
  local old_notify = vim.notify
  local old_defer = vim.defer_fn
  vim.notify = function(msg, level)
    notified = true
  end
  vim.defer_fn = function(fn, ms)
    defer_called = (ms == 5000)
    fn()
  end

  utils.show_notification("hello", vim.log.levels.INFO, 5000)

  MiniTest.expect.equality(true, notified)
  MiniTest.expect.equality(true, defer_called)

  vim.notify = old_notify
  vim.defer_fn = old_defer
end

return T
