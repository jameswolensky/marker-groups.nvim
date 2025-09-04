local MiniTest = require "mini.test"

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      package.loaded["marker-groups"] = nil
      package.loaded["marker-groups.config"] = nil
      package.loaded["marker-groups.state"] = nil
      package.loaded["marker-groups.feedback"] = nil
      package.loaded["marker-groups.pickers.utils"] = nil

      require("marker-groups").setup {
        data_dir = vim.fn.tempname() .. "_marker_groups_test",
        log_level = "debug",
        keymaps = { enabled = false },
      }
    end,
  },
}

T["show_notification delegates to feedback.notify with timeout"] = function()
  local utils = require "marker-groups.pickers.utils"
  local feedback = require "marker-groups.feedback"
  local captured = {}
  local old_fb = feedback.notify
  feedback.notify = function(msg, level, opts)
    table.insert(captured, { msg = msg, level = level, opts = opts })
  end

  utils.show_notification("hello", vim.log.levels.INFO, 5000)

  MiniTest.expect.equality(true, #captured >= 1)
  MiniTest.expect.equality("hello", captured[1].msg)
  MiniTest.expect.equality(vim.log.levels.INFO, captured[1].level)
  MiniTest.expect.equality(5000, captured[1].opts and captured[1].opts.timeout)

  feedback.notify = old_fb
end

return T
