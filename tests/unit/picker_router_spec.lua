local assert = require "luassert"

describe("Picker router and adapters", function()
  before_each(function()
    for k, _ in pairs(package.loaded) do
      if k:match "^marker%-groups" then
        package.loaded[k] = nil
      end
    end
    require("marker-groups").setup {
      data_dir = vim.fn.tempname() .. "_mg_picker_tests",
      keymaps = { enabled = false },
      picker = { provider = "telescope", config = nil },
    }
    require("marker-groups.state").initialize(require("marker-groups.config").get())
  end)

  it("falls back to native when provider is unknown", function()
    local cfg = require "marker-groups.config"
    cfg.update { picker = { provider = "__unknown__", config = nil } }

    local native = require "marker-groups.pickers.native"
    local called = { groups = false, markers = false }
    local orig_groups, orig_markers = native.show_groups, native.show_markers
    native.show_groups = function(opts)
      called.groups = opts ~= nil
      return true
    end
    native.show_markers = function(opts)
      called.markers = opts ~= nil
      return true
    end

    local router = require "marker-groups.picker"
    router.show_groups()
    router.show_markers()

    native.show_groups, native.show_markers = orig_groups, orig_markers
    assert.is_true(called.groups)
    assert.is_true(called.markers)
  end)

  it("passes {} per-call when config is nil", function()
    local cfg = require "marker-groups.config"
    cfg.update { picker = { provider = "telescope", config = nil } }

    -- Replace telescope adapter with a fake that records opts
    local router = require "marker-groups.picker"
    local fake = {
      name = function()
        return "telescope"
      end,
      module_name = "telescope",
      is_ready = function()
        return true
      end,
    }
    local seen_opts_groups, seen_opts_markers
    function fake.show_groups(opts)
      seen_opts_groups = opts
      return true
    end
    function fake.show_markers(opts)
      seen_opts_markers = opts
      return true
    end

    router.register("telescope", fake)
    router.show_groups()
    router.show_markers()

    assert.is_truthy(seen_opts_groups)
    assert.is_truthy(seen_opts_markers)
    assert.are.same({}, seen_opts_groups)
    assert.are.same({}, seen_opts_markers)
  end)

  it("passes user config per-call when config is provided", function()
    local cfg = require "marker-groups.config"
    local ucfg = { layout = { preset = "vscode" }, win = { input = { border = "rounded" } } }
    cfg.update { picker = { provider = "telescope", config = ucfg } }

    local router = require "marker-groups.picker"
    local fake = {
      name = function()
        return "telescope"
      end,
      module_name = "telescope",
      is_ready = function()
        return true
      end,
    }
    local seen
    function fake.show_groups(opts)
      seen = opts
      return true
    end

    router.register("telescope", fake)
    router.show_groups()

    assert.is_table(seen)
    assert.are.same(ucfg, seen)
  end)

  it("falls back to native when provider require() fails", function()
    local cfg = require "marker-groups.config"
    cfg.update { picker = { provider = "telescope", config = {} } }

    local router = require "marker-groups.picker"
    local fake = {
      name = function()
        return "telescope"
      end,
      module_name = "__nonexistent_module__",
      is_ready = function()
        return false
      end,
    }
    router.register("telescope", fake)

    local native = require "marker-groups.pickers.native"
    local called = false
    local orig = native.show_groups
    native.show_groups = function(opts)
      called = true
      return true
    end

    router.show_groups()
    native.show_groups = orig
    assert.is_true(called)
  end)
end)
