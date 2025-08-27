local assert = require "luassert"

describe("interactive group creation input handling", function()
  local groups
  local state
  local config

  local orig_ui_input
  local orig_fn_input

  before_each(function()
    -- ensure fresh plugin/state per test
    local mg = require "marker-groups"
    if mg.is_initialized() then
      mg.reload()
    end
    mg.setup {
      data_dir = vim.fn.tempname() .. "_marker_groups_test",
      log_level = "debug",
      keymaps = { enabled = false },
    }

    groups = require "marker-groups.groups"
    state = require "marker-groups.state"
    config = require "marker-groups.config"

    orig_ui_input = vim.ui.input
    orig_fn_input = vim.fn.input
  end)

  after_each(function()
    vim.ui.input = orig_ui_input
    vim.fn.input = orig_fn_input
  end)

  it("uses fallback when vim.ui.input cancels immediately (unit: prompt_with_limit)", function()
    local input_ui = require "marker-groups.ui.input"
    -- Simulate immediate cancel from UI input
    vim.ui.input = function(opts, cb)
      cb(nil)
    end
    -- Fallback returns a valid name
    vim.fn.input = function()
      return "fallback-group"
    end

    local received
    input_ui.prompt_with_limit({ prompt = "Enter group name:" }, 100, function(v)
      received = v
    end)
    -- Process scheduled callbacks
    vim.wait(100)
    assert.are.equal("fallback-group", received)
  end)

  it("creates group when vim.ui.input provides value", function()
    vim.ui.input = function(opts, cb)
      cb "ui-group"
    end
    -- Ensure fallback would not be called accidentally
    vim.fn.input = function()
      return "should-not-be-used"
    end

    groups.create_group_interactive { auto_switch = false }
    vim.wait(200, function()
      return state.get_all_groups()["ui-group"] ~= nil
    end)

    local all = state.get_all_groups()
    assert.is_not_nil(all["ui-group"])
  end)

  it("does not create group when both ui.input cancels and fallback empty", function()
    vim.ui.input = function(opts, cb)
      cb(nil)
    end
    vim.fn.input = function()
      return ""
    end

    groups.create_group_interactive { auto_switch = false }
    vim.wait(100)

    local all = state.get_all_groups()
    -- Only default should exist (ignore any empty key check)
    assert.is_not_nil(all["default"])
    local extra = {}
    for name, _ in pairs(all) do
      if name ~= "default" then
        table.insert(extra, name)
      end
    end
    assert.are.equal(0, #extra)
  end)
end)
