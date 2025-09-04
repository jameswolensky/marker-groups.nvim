local MiniTest = require "mini.test"

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      for k in pairs(package.loaded) do
        if k:match "^marker%-groups" then
          package.loaded[k] = nil
        end
      end
    end,
  },
}

local function setup_with_picker(picker)
  require("marker-groups").setup { picker = picker, log_level = "error" }
  local status = require("marker-groups.pickers").get_status()
  return status.current_backend
end

T["picker vim maps to vim_ui"] = function()
  local backend = setup_with_picker "vim"
  MiniTest.expect.equality(backend, "vim_ui")
end

T["picker vim_ui selects vim_ui"] = function()
  local backend = setup_with_picker "vim_ui"
  MiniTest.expect.equality(backend, "vim_ui")
end

T["invalid picker falls back to vim_ui"] = function()
  local backend = setup_with_picker "not_a_real_picker"
  MiniTest.expect.equality(backend, "vim_ui")
end

return T
