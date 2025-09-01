local MiniTest = require "mini.test"

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      for k in pairs(package.loaded) do
        if k:match "^marker%-groups" or k:match "^fzf%-lua" then
          package.loaded[k] = nil
        end
      end
      -- stub fzf-lua
      package.loaded["fzf-lua"] = {
        fzf_exec = function(items, opts)
          return true
        end,
      }
      require("marker-groups").setup { picker = "fzf_lua" }
    end,
  },
}

T["fzf-lua backend Enter selects chosen group"] = function()
  local state = require "marker-groups.state"
  local groups = require "marker-groups.groups"
  groups.create_group "dev"
  local called = false
  package.loaded["fzf-lua"] = {
    fzf_exec = function(items, opts)
      called = true
      -- simulate selecting first display (dev)
      opts.actions["default"] { items[1] }
    end,
  }
  require("marker-groups.pickers").show_groups()
  MiniTest.expect.equality(true, called)
  MiniTest.expect.equality("dev", state.get_active_group())
end

T["fzf-lua backend Enter deletes chosen group in delete mode"] = function()
  local state = require "marker-groups.state"
  local groups = require "marker-groups.groups"
  groups.create_group "dev"
  local called = false
  package.loaded["fzf-lua"] = {
    fzf_exec = function(items, opts)
      called = true
      opts.actions["default"] { items[1] }
    end,
  }
  require("marker-groups.pickers").delete_groups()
  MiniTest.expect.equality(true, called)
  MiniTest.expect.equality(nil, state.get_group "dev")
end

return T
