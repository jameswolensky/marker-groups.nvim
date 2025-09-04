local MiniTest = require "mini.test"

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      for k in pairs(package.loaded) do
        if k:match "^marker%-groups" then
          package.loaded[k] = nil
        end
      end
      vim.g.mapleader = "\\"
      require("marker-groups").setup { picker = "vim_ui", log_level = "error" }
    end,
  },
}

T["delete picker excludes default group"] = function()
  local g = require "marker-groups.groups"
  local old_list = g.list_groups
  g.list_groups = function()
    return {
      { name = "default", marker_count = 0, is_active = false },
      { name = "dev", marker_count = 2, is_active = false },
    }
  end

  local captured
  local old_select = vim.ui.select
  vim.ui.select = function(items, opts, on_choice)
    captured = items
  end

  require("marker-groups.pickers").delete_groups()

  MiniTest.expect.equality(type(captured), "table")
  local has_default = false
  for _, it in ipairs(captured or {}) do
    if type(it) == "string" and it:match "^default %(" then
      has_default = true
    end
  end
  MiniTest.expect.equality(has_default, false)

  g.list_groups = old_list
  vim.ui.select = old_select
end

T["delete picker not shown when only default exists"] = function()
  local g = require "marker-groups.groups"
  local old_list = g.list_groups
  g.list_groups = function()
    return {
      { name = "default", marker_count = 0, is_active = false },
    }
  end

  local select_called = false
  local old_select = vim.ui.select
  vim.ui.select = function(items, opts, on_choice)
    select_called = true
  end

  local notified
  local old_notify = vim.notify
  vim.notify = function(msg, level)
    notified = msg
  end

  require("marker-groups.pickers").delete_groups()

  MiniTest.expect.equality(select_called, false)
  local msg = tostring(notified or "")
  MiniTest.expect.equality(msg:find("No groups available to delete", 1, true) ~= nil, true)

  g.list_groups = old_list
  vim.ui.select = old_select
  vim.notify = old_notify
end

return T
