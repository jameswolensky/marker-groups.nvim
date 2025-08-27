local assert = require "luassert"

describe("snacks headless integration", function()
  local state
  local groups
  local markers

  before_each(function()
    package.loaded["snacks"] = nil
    package.loaded["snacks.picker"] = nil
    package.loaded["marker-groups.pickers.snacks"] = nil

    require("marker-groups").setup {
      data_dir = vim.fn.tempname() .. "_mg_snacks_headless_test",
      keymaps = { enabled = false },
      picker = { provider = "snacks" },
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
    local captured
    package.loaded["snacks"] = {
      picker = function(opts)
        assert.is_table(opts.items)
        captured = opts.items
        -- Find the item whose value is g2
        local target
        for _, it in ipairs(captured) do
          if (it.value or it.text or it.label or it.display) == "g2" then
            target = it
            break
          end
        end
        assert.is_table(target)
        local instance = {
          current = function()
            return target
          end,
          close = function() end,
        }
        assert.is_table(opts.actions)
        assert.is_false(opts.actions.accept)
        assert.is_function(opts.keys["<CR>"])
        opts.keys["<CR>"](instance)
      end,
    }

    local picker = require "marker-groups.pickers.snacks"
    local res = picker.show_groups {}
    assert.is_true(res.success)
    assert.equals("g2", state.get_active_group())
  end)

  it("shows markers for the selected group", function()
    local tmp = vim.fn.tempname() .. ".txt"
    vim.fn.writefile({ "a", "b", "c" }, tmp)
    vim.cmd("edit " .. vim.fn.fnameescape(tmp))
    local add_res = markers.add_marker("snacks marker", "g2")
    assert.is_true(add_res.success)
    groups.select_group "g2"

    local displayed
    package.loaded["snacks"] = {
      picker = function(opts)
        displayed = opts.items
      end,
    }
    local picker = require "marker-groups.pickers.snacks"
    local res = picker.show_markers {}
    assert.is_true(res.success)
    assert.is_true(#displayed >= 1)
  end)

  it("deletes selected group via vim.ui confirmation flow", function()
    -- Use the plugin's deletion UI which uses vim.ui.select
    -- First select g2 in group deletion picker, then confirm Yes
    local ui_calls = 0
    local original_ui_select = vim.ui.select
    vim.ui.select = function(items, opts, cb)
      ui_calls = ui_calls + 1
      if ui_calls == 1 then
        -- choose display matching g2
        local choice
        for _, it in ipairs(items) do
          if it:match "^g2 " then
            choice = it
            break
          end
        end
        cb(choice)
      else
        cb "Yes"
      end
    end

    local res = groups.select_group_for_deletion {}
    assert.is_true(res.success)
    vim.ui.select = original_ui_select
    assert.is_nil(state.get_group "g2")
  end)
end)
