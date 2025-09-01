local MiniTest = require "mini.test"

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      -- Fresh load
      package.loaded["marker-groups"] = nil
      package.loaded["marker-groups.pickers"] = nil
      package.loaded["marker-groups.pickers.init"] = nil
      package.loaded["marker-groups.pickers.vim_ui"] = nil
      package.loaded["marker-groups.state"] = nil
      package.loaded["marker-groups.groups"] = nil

      require("marker-groups").setup { picker = "vim_ui" }
    end,
  },
}

T["show_groups deletes selected group via vim.ui.select (Enter)"] = function()
  local state = require "marker-groups.state"
  local groups = require "marker-groups.groups"
  groups.create_group "dev"
  groups.create_group "docs"

  local called = false
  local seen_items = nil
  local orig_select = vim.ui.select
  vim.ui.select = function(items, opts, on_choice)
    called = true
    seen_items = items
    -- choose first to delete it
    on_choice(items[1])
  end

  require("marker-groups.pickers").show_groups()

  -- restore
  vim.ui.select = orig_select

  MiniTest.expect.equality(true, called)
  MiniTest.expect.equality(true, #seen_items >= 2)
  -- After deletion, the selected group should not exist
  local deleted = state.get_group "dev" == nil or state.get_group "docs" == nil
  MiniTest.expect.equality(true, deleted)
end

T["show_markers lists markers in active group via vim.ui.select"] = function()
  local state = require "marker-groups.state"
  local groups = require "marker-groups.groups"
  groups.create_group "work"
  state.set_active_group "work"

  -- add markers directly in state
  local tmp = vim.fn.tempname()
  vim.fn.writefile({ "a", "b", "c", "d" }, tmp)
  state.add_marker({ buffer_path = tmp, start_line = 2, end_line = 2, annotation = "B" }, "work")
  state.add_marker({ buffer_path = tmp, start_line = 3, end_line = 3, annotation = "C" }, "work")

  local called = false
  local seen_items = nil
  local orig_select = vim.ui.select
  vim.ui.select = function(items, opts, on_choice)
    called = true
    seen_items = items
    -- don't select to avoid navigation; just validate items
    if on_choice then
      on_choice(nil)
    end
  end

  require("marker-groups.pickers").show_markers()

  vim.ui.select = orig_select

  MiniTest.expect.equality(true, called)
  -- two markers inserted
  MiniTest.expect.equality(true, #seen_items >= 2)
end

return T
