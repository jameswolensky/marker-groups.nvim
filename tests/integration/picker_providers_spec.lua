local assert = require "luassert"

describe("picker provider selection order", function()
  before_each(function()
    package.loaded["snacks"] = nil
    package.loaded["mini.pick"] = nil
    package.loaded["telescope"] = nil
    local mg = require "marker-groups"
    mg.setup {
      data_dir = vim.fn.tempname() .. "_mg_picker_test",
      keymaps = { enabled = false },
      picker = { provider = "auto" },
    }
  end)

  it("prefers telescope over others when all available", function()
    package.loaded["telescope"] = { _version = "test" }
    package.loaded["snacks"] = { picker = { open = function(_) end } }
    package.loaded["mini.pick"] = { start = function(_) end }
    local picker = require "marker-groups.picker"
    assert.are.equal("telescope", picker.get_provider_name())
  end)

  it("falls back to snacks when telescope not available", function()
    package.loaded["snacks"] = { picker = { open = function(_) end } }
    package.loaded["mini.pick"] = { start = function(_) end }
    local picker = require "marker-groups.picker"
    assert.are.equal("snacks", picker.get_provider_name())
  end)

  it("falls back to mini when telescope/snacks not available", function()
    package.loaded["mini.pick"] = { start = function(_) end }
    local picker = require "marker-groups.picker"
    assert.are.equal("mini", picker.get_provider_name())
  end)
end)
