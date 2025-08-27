local assert = require "luassert"

describe("snacks picker API compatibility", function()
  local state
  local config
  local groups

  before_each(function()
    package.loaded["snacks"] = nil
    package.loaded["marker-groups.pickers.snacks"] = nil
    require("marker-groups").setup {
      data_dir = vim.fn.tempname() .. "_mg_snacks_test",
      keymaps = { enabled = false },
      picker = { provider = "snacks" },
    }
    state = require "marker-groups.state"
    config = require "marker-groups.config"
    groups = require "marker-groups.groups"
    state.initialize(config.get())

    groups.create_group "g1"
    groups.create_group "g2"
  end)

  it("supports snacks.picker function API", function()
    local selected
    package.loaded["snacks"] = {
      picker = function(opts)
        assert.is_table(opts)
        assert.is_table(opts.items)
        -- Simulate choosing the first item
        if opts.action then
          opts.action(opts.items[1])
        end
      end,
    }

    local picker = require "marker-groups.pickers.snacks"
    local res = picker.show_groups { prompt = "Select" }
    assert.is_true(res.success)
  end)

  it("supports snacks.picker.open method API", function()
    package.loaded["snacks"] = {
      picker = {
        open = function(opts)
          assert.is_table(opts)
          assert.is_table(opts.items)
          if opts.action then
            opts.action(opts.items[1])
          end
        end,
      },
    }

    local picker = require "marker-groups.pickers.snacks"
    local res = picker.show_groups { prompt = "Select" }
    assert.is_true(res.success)
  end)

  it("supports snacks.picker module API (require 'snacks.picker')", function()
    package.loaded["snacks"] = {}
    package.loaded["snacks.picker"] = {
      open = function(opts)
        assert.is_table(opts)
        assert.is_table(opts.items)
        if opts.action then
          opts.action(opts.items[1])
        end
      end,
    }

    local picker = require "marker-groups.pickers.snacks"
    local res = picker.show_groups { prompt = "Select" }
    assert.is_true(res.success)
  end)

  it("binds <CR> to select group via picker instance", function()
    -- Stub snacks with function-style picker
    package.loaded["snacks"] = {
      picker = function(opts)
        assert.is_table(opts)
        assert.is_table(opts.items)
        assert.is_table(opts.keys)

        -- Simulate a picker instance
        local selected = opts.items[2] -- choose second group (g2)
        local instance = {
          current = function()
            return selected
          end,
          close = function() end,
        }

        -- Call our <CR> keybinding handler
        assert.is_table(opts.actions)
        assert.is_false(opts.actions.accept)
        assert.is_function(opts.keys["<CR>"])
        opts.keys["<CR>"](instance)
      end,
    }

    local picker = require "marker-groups.pickers.snacks"
    local res = picker.show_groups { prompt = "Select" }
    assert.is_true(res.success)

    -- Verify that active group changed from default
    local active = state.get_active_group()
    assert.not_equals("default", active)
  end)
end)
