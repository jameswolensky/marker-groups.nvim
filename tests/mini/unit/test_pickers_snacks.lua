local MiniTest = require "mini.test"

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      for k in pairs(package.loaded) do
        if k:match "^marker%-groups" or k:match "^snacks" then
          package.loaded[k] = nil
        end
      end
      require("marker-groups").setup { picker = "snacks" }
    end,
  },
}

T["snacks backend Enter deletes selected group"] = function()
  local state = require "marker-groups.state"
  local groups = require "marker-groups.groups"
  groups.create_group "dev"

  local called = false
  package.loaded["snacks"] = {
    picker = function(opts)
      called = true
      -- simulate selecting first item (dev)
      local first = opts.source.items[1]
      opts.actions["default"] { { name = first.name } }
    end,
  }

  require("marker-groups.pickers").show_groups()

  MiniTest.expect.equality(true, called)
  -- group 'dev' should be deleted
  MiniTest.expect.equality(nil, state.get_group "dev")
end

return T
