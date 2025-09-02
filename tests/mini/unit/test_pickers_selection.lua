local MiniTest = require "mini.test"

local T = MiniTest.new_set()

local function setup_with_picker(picker_name)
  local child = MiniTest.new_child_neovim()
  child.restart { "--headless", "-u", "scripts/minimal_init.lua" }
  child.lua [[vim.opt.runtimepath:append(vim.fn.getcwd())]]
  child.lua(string.format([[require('marker-groups').setup({ picker = %q })]], picker_name))
  return child
end

T["defaults to vim_ui when invalid picker"] = function()
  local child = setup_with_picker "snacsk"
  local backend = child.lua [[local s=require('marker-groups.pickers').get_status(); return s.current_backend]]
  MiniTest.expect.equality(backend, "vim_ui")
  child.stop()
end

T["alias 'vim' selects vim_ui backend"] = function()
  local child = setup_with_picker "vim"
  local backend = child.lua [[local s=require('marker-groups.pickers').get_status(); return s.current_backend]]
  MiniTest.expect.equality(backend, "vim_ui")
  child.stop()
end

T["alias 'fzf-lua' selects fzf_lua when available else falls back to vim_ui"] = function()
  local child = setup_with_picker "fzf-lua"
  local has_fzf = child.lua [[return pcall(require, 'fzf-lua')]]
  local backend = child.lua [[local s=require('marker-groups.pickers').get_status(); return s.current_backend]]
  if has_fzf then
    MiniTest.expect.equality(backend, "fzf_lua")
  else
    MiniTest.expect.equality(backend, "vim_ui")
  end
  child.stop()
end

return T
