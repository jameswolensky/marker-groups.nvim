local MiniTest = require "mini.test"

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      for k in pairs(package.loaded) do
        if k:match "^marker%-groups" then
          package.loaded[k] = nil
        end
      end
      vim.g.mapleader = "\\"
      require("marker-groups").setup {}
    end,
  },
}

local function term(keys)
  return vim.api.nvim_replace_termcodes(keys, true, false, true)
end

local function press(keys)
  vim.api.nvim_feedkeys(term(keys), "mx", false)
  vim.wait(20)
end

T["<leader>mgs triggers pickers.show_groups"] = function()
  local called = { show = false, delete = false }
  package.loaded["marker-groups.pickers"] = {
    show_groups = function()
      called.show = true
    end,
    delete_groups = function()
      called.delete = true
    end,
  }

  press "<leader>mgs"

  MiniTest.expect.equality(true, called.show)
  MiniTest.expect.equality(false, called.delete)
end

T["<leader>mgd triggers pickers.delete_groups"] = function()
  local called = { show = false, delete = false }
  package.loaded["marker-groups.pickers"] = {
    show_groups = function()
      called.show = true
    end,
    delete_groups = function()
      called.delete = true
    end,
  }

  press "<leader>mgd"

  MiniTest.expect.equality(false, called.show)
  MiniTest.expect.equality(true, called.delete)
end

T["expected group keymaps exist"] = function()
  local maps = vim.api.nvim_get_keymap "n"
  local have = {}
  for _, m in ipairs(maps) do
    have[m.lhs] = true
  end
  MiniTest.expect.equality(true, have[term "<leader>mgs"])
  MiniTest.expect.equality(true, have[term "<leader>mgd"])
  MiniTest.expect.equality(true, have[term "<leader>mgc"])
  MiniTest.expect.equality(true, have[term "<leader>mgl"])
  MiniTest.expect.equality(true, have[term "<leader>mgr"])
  MiniTest.expect.equality(true, have[term "<leader>mgi"])
  MiniTest.expect.equality(true, have[term "<leader>mgb"])
end

T["<leader>mtm triggers pickers.show_markers"] = function()
  local called = { markers = false, groups = false }
  package.loaded["marker-groups.pickers"] = {
    show_markers = function()
      called.markers = true
    end,
    show_groups = function()
      called.groups = true
    end,
    delete_groups = function() end,
  }
  press "<leader>mtm"
  MiniTest.expect.equality(true, called.markers)
end

T["<leader>mtg triggers pickers.show_groups"] = function()
  local called = { markers = false, groups = false }
  package.loaded["marker-groups.pickers"] = {
    show_markers = function() end,
    show_groups = function()
      called.groups = true
    end,
    delete_groups = function() end,
  }
  press "<leader>mtg"
  MiniTest.expect.equality(true, called.groups)
end

return T
