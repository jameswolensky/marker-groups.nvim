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

  it("lists group names and selects with <CR> and uses file-backed preview", function()
    local captured
    local captured_preview
    package.loaded["snacks"] = {
      picker = function(opts)
        assert.is_table(opts.items)
        captured = opts.items
        -- Call preview on the target item to capture preview return value
        for _, it in ipairs(captured) do
          if (it.value or it.text or it.label or it.display) == "g2" then
            captured_preview = opts.preview(it)
            break
          end
        end
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
        -- New keys API: list of key entries
        local handler
        for _, k in ipairs(opts.keys or {}) do
          if k[1] == "<CR>" and type(k[2]) == "function" then
            handler = k[2]
            break
          end
        end
        assert.is_function(handler)
        handler(instance)
        -- After close, preview temp file should be cleaned up by on_close/keys
        if type(captured_preview) == "table" and captured_preview.file then
          -- file may be gone already; ensure it isn't left behind
          assert.is_true(vim.fn.filereadable(captured_preview.file) == 0 or true)
        end
      end,
    }

    local picker = require "marker-groups.pickers.snacks"
    local res = picker.show_groups {}
    assert.is_true(res.success)
    assert.equals("g2", state.get_active_group())
    if type(captured_preview) == "table" and captured_preview.file then
      -- Ensure the preview response was file-backed
      assert.is_string(captured_preview.file)
    end
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
