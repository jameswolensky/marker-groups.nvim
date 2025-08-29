local assert = require "luassert"

describe("snacks picker adapter", function()
  it("uses state.get_group_names() to build items", function()
    for k, _ in pairs(package.loaded) do
      if k:match "^marker%-groups" then
        package.loaded[k] = nil
      end
    end
    require("marker-groups").setup { keymaps = { enabled = false } }
    local config = require "marker-groups.config"
    local state = require "marker-groups.state"
    state.initialize(config.get())

    local groups = require "marker-groups.groups"
    groups.create_group "a"
    groups.create_group "b"

    -- stub snacks API
    package.loaded["snacks"] = {
      picker = {
        pick = function(opts)
          assert.is_table(opts)
          assert.is_table(opts.items)
          local names = opts.items
          assert.is_true(vim.tbl_contains(names, "default"))
          assert.is_true(vim.tbl_contains(names, "a"))
          assert.is_true(vim.tbl_contains(names, "b"))
        end,
      },
    }

    local snacks_adapter = require "marker-groups.pickers.snacks"
    assert.has_no.errors(function()
      snacks_adapter.show_groups {}
    end)
  end)
end)
