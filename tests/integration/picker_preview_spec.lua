local assert = require "luassert"

describe("picker group preview content", function()
  before_each(function()
    package.loaded["snacks"] = nil
    package.loaded["mini.pick"] = nil
    package.loaded["marker-groups.pickers.snacks"] = nil
    package.loaded["marker-groups.pickers.mini"] = nil

    require("marker-groups").setup {
      data_dir = vim.fn.tempname() .. "_mg_prev_test",
      keymaps = { enabled = false },
      picker = { provider = "snacks" },
    }

    local state = require "marker-groups.state"
    local config = require "marker-groups.config"
    local groups = require "marker-groups.groups"
    local markers = require "marker-groups.markers"
    state.initialize(config.get())

    groups.create_group "gprev"
    groups.select_group "gprev"

    -- Create a temp file and a marker to appear in preview
    vim.cmd "enew"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "A", "B", "C" })
    local tmp = "/tmp/mg_prev_" .. os.time() .. ".txt"
    vim.cmd("write " .. tmp)
    markers.add_marker "hello"
  end)

  it("snacks group preview renders markers via preview function", function()
    local pickermod = require "marker-groups.pickers.snacks"

    local opened = {}
    package.loaded["snacks"] = {
      picker = function(opts)
        assert.is_table(opts.items)
        assert.is_function(opts.preview)
        local it = opts.items[1]
        local text = opts.preview(it)
        assert.is_truthy(text:match "📌 Markers:")
        -- Pretend we opened; trigger action to ensure no crash
        if opts.action then
          opts.action(it)
        end
        table.insert(opened, it)
      end,
    }

    local res = pickermod.show_groups { prompt = "Select" }
    assert.is_true(res.success)
    assert.is_truthy(opened[1])
  end)

  it("mini.pick group preview returns marker list text", function()
    require("marker-groups.config").update { picker = { provider = "mini" } }
    package.loaded["mini.pick"] = {
      start = function(opts)
        assert.is_table(opts)
        local src = opts.source or {}
        assert.is_function(src.preview)
        local first = src.items and src.items[1]
        local text = src.preview(first)
        assert.is_truthy(text:match "📌 Markers:")
      end,
    }

    local pickermod = require "marker-groups.pickers.mini"
    local res = pickermod.show_groups { prompt = "Select" }
    assert.is_true(res.success)
  end)
end)
