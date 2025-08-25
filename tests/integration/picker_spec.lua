local assert = require "luassert"

describe("picker provider integration", function()
  before_each(function()
    package.loaded["snacks"] = nil
    package.loaded["mini.pick"] = nil
    require("marker-groups").setup {
      data_dir = "/tmp/marker-groups-test",
      keymaps = { enabled = false },
      picker = { provider = "auto" },
    }
    local state = require "marker-groups.state"
    local config = require "marker-groups.config"
    state.initialize(config.get())
    state.create_group "g1"
    state.set_active_group "g1"
  end)

  it("falls back to vim.ui when no providers available", function()
    local picker = require "marker-groups.picker"
    assert.are.equal("vim", picker.get_provider_name())
  end)

  it("uses mini.pick when configured and available", function()
    package.loaded["mini.pick"] = {
      start = function(_) end,
    }
    local picker = require "marker-groups.picker"
    require("marker-groups.config").update { picker = { provider = "mini" } }
    assert.are.equal("mini", picker.get_provider_name())
  end)

  it("uses snacks when configured and available", function()
    package.loaded["snacks"] = {
      picker = {
        open = function(_) end,
      },
    }
    local picker = require "marker-groups.picker"
    require("marker-groups.config").update { picker = { provider = "snacks" } }
    assert.are.equal("snacks", picker.get_provider_name())
  end)

  it("uses telescope when configured and available", function()
    package.loaded["telescope"] = { _version = "test" }
    local picker = require "marker-groups.picker"
    require("marker-groups.config").update { picker = { provider = "telescope" } }
    assert.are.equal("telescope", picker.get_provider_name())
  end)
end)
