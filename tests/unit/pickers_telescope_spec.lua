local assert = require "luassert"

describe("telescope picker adapter", function()
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
    groups.create_group "g1"
    groups.create_group "g2"

    -- stub telescope pieces
    package.loaded["telescope"] = true
    package.loaded["telescope.pickers"] = {
      new = function(opts, spec)
        -- spec.finder will be created via finders.new_table(groups)
        assert.is_table(spec)
        assert.is_table(spec.finder)
        return { find = function() end }
      end,
    }
    package.loaded["telescope.finders"] = {
      new_table = function(list)
        assert.is_table(list)
        -- list should be an array of names from state
        assert.is_true(vim.tbl_contains(list, "default"))
        assert.is_true(vim.tbl_contains(list, "g1"))
        assert.is_true(vim.tbl_contains(list, "g2"))
        return { results = list }
      end,
    }
    package.loaded["telescope.config"] = { values = {
      generic_sorter = function()
        return function() end
      end,
    } }
    package.loaded["telescope.actions"] = { close = function() end }
    package.loaded["telescope.actions.state"] = {
      get_selected_entry = function()
        return { [1] = "g1" }
      end,
    }

    local tel = require "marker-groups.pickers.telescope"
    assert.has_no.errors(function()
      tel.show_groups {}
    end)
  end)
end)
