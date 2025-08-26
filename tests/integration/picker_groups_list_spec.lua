local assert = require "luassert"

describe("picker groups list shows all groups", function()
  before_each(function()
    package.loaded["snacks"] = nil
    package.loaded["mini.pick"] = nil
    package.loaded["marker-groups.pickers.snacks"] = nil
    package.loaded["marker-groups.pickers.mini"] = nil
    package.loaded["marker-groups.telescope"] = nil

    require("marker-groups").setup {
      data_dir = vim.fn.tempname() .. "_mg_list_test",
      keymaps = { enabled = false },
    }

    local state = require "marker-groups.state"
    local config = require "marker-groups.config"
    local groups = require "marker-groups.groups"
    state.initialize(config.get())

    -- Ensure a few groups exist including default
    groups.create_group "alpha"
    groups.create_group "beta"
  end)

  it("snacks lists default and custom groups", function()
    require("marker-groups.config").update { picker = { provider = "snacks" } }

    local seen = {}
    package.loaded["snacks"] = {
      picker = function(opts)
        for _, it in ipairs(opts.items or {}) do
          local label = (type(it) == "string" and it) or (type(it) == "table" and it.text)
          if label then
            seen[label] = true
          end
        end
      end,
    }

    local pickermod = require "marker-groups.pickers.snacks"
    local res = pickermod.show_groups { prompt = "Select" }
    assert.is_true(res.success)
    assert.is_true(seen["default"])
    assert.is_true(seen["alpha"])
    assert.is_true(seen["beta"])
  end)

  it("mini.pick lists default and custom groups", function()
    require("marker-groups.config").update { picker = { provider = "mini" } }

    local seen = {}
    package.loaded["mini.pick"] = {
      start = function(opts)
        for _, t in ipairs(opts.source.items or {}) do
          seen[t] = true
        end
      end,
    }

    local pickermod = require "marker-groups.pickers.mini"
    local res = pickermod.show_groups { prompt = "Select" }
    assert.is_true(res.success)
    assert.is_true(seen["default"])
    assert.is_true(seen["alpha"])
    assert.is_true(seen["beta"])
  end)

  it("telescope lists default and custom groups", function()
    -- Stub telescope finder to capture entries
    local entries
    package.loaded["telescope"] = {}
    package.loaded["telescope.pickers"] = {
      new = function(_, spec)
        entries = {}
        for _, e in ipairs(spec.finder.results) do
          table.insert(entries, e)
        end
        return { find = function() end }
      end,
    }
    package.loaded["telescope.finders"] = {
      new_table = function(tbl)
        return tbl
      end,
    }
    package.loaded["telescope.config"] =
      { values = {
        generic_sorter = function()
          return function() end
        end,
      } }
    package.loaded["telescope.actions"] = { select_default = { replace = function() end }, close = function() end }
    package.loaded["telescope.actions.state"] = {
      get_selected_entry = function()
        return nil
      end,
    }
    package.loaded["telescope.previewers"] = {
      new_buffer_previewer = function(_)
        return {}
      end,
    }

    local tel = require "marker-groups.telescope"
    tel.show_groups {}

    local names = {}
    for _, e in ipairs(entries or {}) do
      names[e.name] = true
    end
    assert.is_true(names["default"])
    assert.is_true(names["alpha"])
    assert.is_true(names["beta"])
  end)
end)
