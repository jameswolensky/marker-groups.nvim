local MiniTest = require "mini.test"

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      for k in pairs(package.loaded) do
        if k:match "^marker%-groups" or k:match "^snacks" then
          package.loaded[k] = nil
        end
      end
      -- Stub Snacks BEFORE setup so backend detection picks it
      package.loaded["snacks.picker"] = true
      package.loaded["snacks"] = {
        picker = function(opts)
          -- no-op default; individual tests will override behavior
        end,
      }
      require("marker-groups").setup { picker = "snacks" }
    end,
  },
}

T["snacks backend Enter selects the chosen group (not delete)"] = function()
  local state = require "marker-groups.state"
  local groups = require "marker-groups.groups"
  groups.create_group "dev"

  local called = false
  package.loaded["snacks"] = {
    picker = function(opts)
      called = true
      -- find the 'dev' item regardless of ordering
      local chosen
      for _, it in ipairs(opts.source.items or {}) do
        if it.name == "dev" then
          chosen = it
          break
        end
      end
      chosen = chosen or opts.source.items[1]
      opts.actions["default"] { { name = chosen.name, text = chosen.text } }
    end,
  }

  require("marker-groups.pickers.snacks").show_groups()

  MiniTest.expect.equality(true, called)
  -- expectation: selecting should activate the group, not delete it
  MiniTest.expect.equality("dev", state.get_active_group())
  MiniTest.expect.equality(state.get_group "dev" ~= nil, true)
end

-- Do not return here; more tests below and we'll return both sets at the end

-- New failing repro for table `value` causing concat error in actions
-- This mirrors Snacks passing structured items where `value` can be a table
-- Expectation pre-fix: running actions should not error; current behavior errors
T["repro: selecting with table value currently errors (should not)"] = function()
  -- Override Snacks stub to simulate table value shape
  package.loaded["snacks"] = {
    picker = function(opts)
      local item = {
        text = "dev (0 markers)",
        name = "dev",
        value = { name = "dev" },
      }
      opts.actions["default"] { item }
    end,
  }
  require("marker-groups").setup { picker = "snacks" }
  local groups = require "marker-groups.groups"
  local state = require "marker-groups.state"
  groups.create_group "dev"

  -- Intentionally call without expecting error to demonstrate failing behavior
  -- Current bug: this errors with "attempt to concatenate a table value"
  require("marker-groups.pickers.snacks").show_groups()
end
return T
