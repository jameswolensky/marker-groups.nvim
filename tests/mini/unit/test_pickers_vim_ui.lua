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

T["show_groups selects chosen group via vim.ui.select (Enter)"] = function()
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
    local default_disp = groups.format_group_info({ name = "default", marker_count = 0, is_active = true }, "short")
    local choice = nil
    for _, item in ipairs(items) do
      if item ~= default_disp then
        choice = item
        break
      end
    end
    on_choice(choice)
  end

  require("marker-groups.pickers").show_groups()

  -- restore
  vim.ui.select = orig_select

  MiniTest.expect.equality(true, called)
  MiniTest.expect.equality(true, #seen_items >= 2)
  MiniTest.expect.equality(true, state.get_active_group() == "dev" or state.get_active_group() == "docs")
end

T["show_groups includes default group in list"] = function()
  local groups = require "marker-groups.groups"
  local expected = groups.format_group_info({ name = "default", marker_count = 0, is_active = true }, "short")

  local seen_items = nil
  local orig_select = vim.ui.select
  vim.ui.select = function(items, opts, on_choice)
    seen_items = items
    if on_choice then
      on_choice(nil)
    end
  end

  require("marker-groups.pickers").show_groups()

  vim.ui.select = orig_select

  local found = false
  if seen_items then
    for _, v in ipairs(seen_items) do
      if v == expected then
        found = true
        break
      end
    end
  end

  MiniTest.expect.equality(true, found)
end
T["delete_groups deletes chosen group via vim.ui.select (Enter)"] = function()
  local state = require "marker-groups.state"
  local groups = require "marker-groups.groups"
  groups.create_group "dev"
  groups.create_group "docs"

  local called = false
  local orig_select = vim.ui.select
  vim.ui.select = function(items, opts, on_choice)
    called = true
    local target = groups.format_group_info({ name = "dev", marker_count = 0, is_active = false }, "short")
    local selected = nil
    for _, item in ipairs(items) do
      if item == target then
        selected = item
        break
      end
    end
    on_choice(selected)
  end

  require("marker-groups.pickers").delete_groups()

  vim.ui.select = orig_select

  MiniTest.expect.equality(true, called)
  MiniTest.expect.equality(nil, state.get_group "dev")
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
