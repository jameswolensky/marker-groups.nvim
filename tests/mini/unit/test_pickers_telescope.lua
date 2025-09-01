local MiniTest = require "mini.test"

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      for k in pairs(package.loaded) do
        if k:match "^marker%-groups" or k:match "^telescope" then
          package.loaded[k] = nil
        end
      end
      require("marker-groups").setup { picker = "telescope" }
    end,
  },
}

T["telescope backend Enter selects chosen group"] = function()
  local state = require "marker-groups.state"
  local groups = require "marker-groups.groups"
  groups.create_group "dev"

  local saved_replace
  local actions = {
    select_default = {
      replace = function(fn)
        saved_replace = fn
      end,
    },
    close = function() end,
  }
  local action_state = {
    get_selected_entry = function()
      return { value = "dev" }
    end,
  }

  package.loaded["telescope.actions"] = actions
  package.loaded["telescope.actions.state"] = action_state
  package.loaded["telescope.config"] = { values = {} }
  package.loaded["telescope.finders"] = {
    new_table = function(tbl)
      return tbl
    end,
  }
  package.loaded["telescope.previewers"] = {
    new_buffer_previewer = function(spec)
      return spec
    end,
  }
  package.loaded["telescope.pickers"] = {
    new = function(opts, spec)
      -- Immediately invoke attach_mappings to install replacement
      if spec.attach_mappings then
        spec.attach_mappings(1, function() end)
      end
      return {
        find = function()
          -- Simulate pressing Enter
          if saved_replace then
            saved_replace()
          end
        end,
      }
    end,
  }

  require("marker-groups.pickers").show_groups()

  MiniTest.expect.equality("dev", state.get_active_group())
end

T["telescope backend Enter deletes chosen group in delete mode"] = function()
  local state = require "marker-groups.state"
  local groups = require "marker-groups.groups"
  groups.create_group "dev"

  local saved_replace
  local actions = {
    select_default = {
      replace = function(fn)
        saved_replace = fn
      end,
    },
    close = function() end,
  }
  local action_state = {
    get_selected_entry = function()
      return { value = "dev" }
    end,
  }

  package.loaded["telescope.actions"] = actions
  package.loaded["telescope.actions.state"] = action_state
  package.loaded["telescope.config"] = { values = {} }
  package.loaded["telescope.finders"] = {
    new_table = function(tbl)
      return tbl
    end,
  }
  package.loaded["telescope.previewers"] = {
    new_buffer_previewer = function(spec)
      return spec
    end,
  }
  package.loaded["telescope.pickers"] = {
    new = function(opts, spec)
      if spec.attach_mappings then
        spec.attach_mappings(1, function() end)
      end
      return {
        find = function()
          if saved_replace then
            saved_replace()
          end
        end,
      }
    end,
  }

  require("marker-groups.pickers").delete_groups()

  MiniTest.expect.equality(nil, state.get_group "dev")
end

return T
