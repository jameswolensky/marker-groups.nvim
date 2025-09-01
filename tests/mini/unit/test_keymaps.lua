local MiniTest = require "mini.test"

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      -- reset plugin and pickers
      for k in pairs(package.loaded) do
        if k:match "^marker%-groups" then
          package.loaded[k] = nil
        end
      end
      -- ensure a predictable leader
      vim.g.mapleader = "\\"
      require("marker-groups").setup {}
    end,
  },
}

local function term(keys)
  return vim.api.nvim_replace_termcodes(keys, true, false, true)
end

local function press(keys)
  vim.api.nvim_feedkeys(term(keys), "nx", false)
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
  -- Defaults: prefix <leader>m
  MiniTest.expect.equality(true, have[term "<leader>mgs"]) -- select
  MiniTest.expect.equality(true, have[term "<leader>mgd"]) -- delete
  MiniTest.expect.equality(true, have[term "<leader>mgc"]) -- create
  MiniTest.expect.equality(true, have[term "<leader>mgl"]) -- list
  MiniTest.expect.equality(true, have[term "<leader>mgr"]) -- rename
  MiniTest.expect.equality(true, have[term "<leader>mgi"]) -- info
  MiniTest.expect.equality(true, have[term "<leader>mgb"]) -- from_branch
end

return T
