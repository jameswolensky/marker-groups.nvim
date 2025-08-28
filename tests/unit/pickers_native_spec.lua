local assert = require "luassert"

describe("native picker adapter", function()
  before_each(function()
    for k, _ in pairs(package.loaded) do
      if k:match "^marker%-groups" then
        package.loaded[k] = nil
      end
    end
    require("marker-groups").setup { keymaps = { enabled = false } }
    local config = require "marker-groups.config"
    require("marker-groups.state").initialize(config.get())
  end)

  it("uses state.get_group_names() and does not call groups.get_group_names()", function()
    -- create extra groups
    local groups_mod = require "marker-groups.groups"
    groups_mod.create_group "alpha"
    groups_mod.create_group "beta"

    -- Ensure the old (nonexistent) API path would fail if used
    local groups_loaded = package.loaded["marker-groups.groups"]
    groups_loaded.get_group_names = nil

    local selected
    local orig_select = vim.ui.select
    vim.ui.select = function(items, opts, cb)
      -- items should match state.get_group_names() including default
      assert.is_true(vim.tbl_contains(items, "default"))
      assert.is_true(vim.tbl_contains(items, "alpha"))
      assert.is_true(vim.tbl_contains(items, "beta"))
      if cb then
        cb "alpha"
      end
    end

    local native = require "marker-groups.pickers.native"
    assert.has_no.errors(function()
      native.show_groups {}
    end)

    vim.ui.select = orig_select
  end)
end)
