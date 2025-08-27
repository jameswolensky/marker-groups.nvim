local assert = require "luassert"

describe("mini.pick headless integration", function()
  local state
  local groups
  local markers

  before_each(function()
    package.loaded["mini.pick"] = nil
    package.loaded["marker-groups.pickers.mini"] = nil

    require("marker-groups").setup {
      data_dir = vim.fn.tempname() .. "_mg_mini_test",
      keymaps = { enabled = false },
      picker = { provider = "mini" },
    }

    local config = require "marker-groups.config"
    state = require "marker-groups.state"
    groups = require "marker-groups.groups"
    markers = require "marker-groups.markers"
    state.initialize(config.get())

    groups.create_group "g1"
    groups.create_group "g2"
  end)

  it("lists group names and selects with <CR>", function()
    local captured_items
    package.loaded["mini.pick"] = {
      start = function(opts)
        assert.is_table(opts)
        assert.is_table(opts.source)
        captured_items = opts.source.items
        -- Choose the item corresponding to g2 by label match
        local choose_item = nil
        for _, s in ipairs(captured_items) do
          if s:match "^g2 %(" then
            choose_item = s
            break
          end
        end
        assert.is_string(choose_item)
        opts.source.choose(choose_item)
      end,
    }

    local picker = require "marker-groups.pickers.mini"
    local res = picker.show_groups { prompt = "Select" }
    assert.is_true(res.success)

    assert.is_true(vim.tbl_contains(captured_items, "g1 (0 markers)"))
    assert.is_true(vim.tbl_contains(captured_items, "g2 (0 markers)"))

    local active = state.get_active_group()
    assert.equals("g2", active)
  end)

  it("deletes selected group via confirmation flow", function()
    -- Ensure g2 exists
    assert.is_truthy(state.get_group "g2")

    local ui_calls = 0
    local original_ui_select = vim.ui.select
    vim.ui.select = function(items, opts, cb)
      ui_calls = ui_calls + 1
      if ui_calls == 1 then
        -- First prompt: choose group display containing g2
        local choice
        for _, it in ipairs(items) do
          if it:match "^g2 " then
            choice = it
            break
          end
        end
        cb(choice)
      else
        -- Second prompt: confirmation Yes/No
        cb "Yes"
      end
    end

    local res = groups.select_group_for_deletion {}
    assert.is_true(res.success)

    -- Restore UI
    vim.ui.select = original_ui_select

    -- g2 should be deleted
    assert.is_nil(state.get_group "g2")
  end)

  it("shows markers for the selected group", function()
    -- Prepare a temp file with content
    local tmp = vim.fn.tempname() .. ".txt"
    local lines = { "one", "two", "three", "four", "five" }
    vim.fn.writefile(lines, tmp)

    -- Open buffer and add a marker to g2
    vim.cmd("edit " .. vim.fn.fnameescape(tmp))
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    local add_res = markers.add_marker("mini test marker", "g2")
    assert.is_true(add_res.success)

    -- Activate g2 then invoke markers picker
    groups.select_group "g2"

    local displayed
    package.loaded["mini.pick"] = {
      start = function(opts)
        displayed = opts.source.items
      end,
    }

    local picker = require "marker-groups.pickers.mini"
    local res = picker.show_markers {}
    assert.is_true(res.success)
    assert.is_true(#displayed >= 1)
    assert.is_true(displayed[1]:match(vim.fn.fnamemodify(tmp, ":t")) ~= nil)
  end)
end)
