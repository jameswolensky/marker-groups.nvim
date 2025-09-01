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

return T
