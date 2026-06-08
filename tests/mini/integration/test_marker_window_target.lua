local MiniTest = require "mini.test"
local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      for k in pairs(package.loaded) do
        if k:match "^marker%-groups" then
          package.loaded[k] = nil
        end
      end
      require("marker-groups").setup {
        data_dir = vim.fn.tempname() .. "_mg_wintarget",
        keymaps = { enabled = false },
      }
    end,
  },
}

T["add_marker_range targets the captured buffer not the current window"] = function()
  local markers = require "marker-groups.markers"
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local right = dir .. "/right.lua"
  local left = dir .. "/left.lua"
  vim.fn.writefile({ "right one", "right two", "right three" }, right)
  vim.fn.writefile({ "left one", "left two", "left three" }, left)

  vim.cmd("edit " .. right)
  local right_buf = vim.api.nvim_get_current_buf()
  vim.cmd("vsplit " .. left)

  local result = markers.add_marker_range(2, 2, "on right", nil, right_buf)

  MiniTest.expect.equality(result.success, true)
  MiniTest.expect.equality(result.value.buffer_path:match "right%.lua$" ~= nil, true)
  MiniTest.expect.equality(result.value.buffer_path:match "left%.lua$" == nil, true)
  pcall(vim.cmd, "only")
end

return T
