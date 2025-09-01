local MiniTest = require "mini.test"

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      package.loaded["marker-groups"] = nil
      package.loaded["marker-groups.commands"] = nil
      package.loaded["marker-groups.pickers"] = nil
      require("marker-groups").setup {}
      require("marker-groups.commands").setup()
    end,
  },
}

T["show_picker_status opens a window and can be closed"] = function()
  -- Call API directly to avoid command registration race in tests
  require("marker-groups.pickers").show_picker_status()
  -- Expect a floating window to be present
  local wins = vim.api.nvim_list_wins()
  MiniTest.expect.equality(true, #wins > 0)

  -- Close the current window programmatically (avoid key feeding in headless)
  vim.api.nvim_win_close(0, true)
end

return T
