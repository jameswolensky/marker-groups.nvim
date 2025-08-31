local MiniTest = require "mini.test"

local T = MiniTest.new_set()

local function with_child(fn)
  local child = MiniTest.new_child_neovim()
  child.restart { "--headless", "-u", "scripts/minimal_init.lua" }
  local ok, err = pcall(fn, child)
  child.stop()
  if not ok then
    error(err)
  end
end

T["drawer config / defaults and validation"] = function()
  with_child(function(child)
    child.lua [[require('marker-groups').setup({ data_dir = vim.fn.tempname() .. '_mg_ui', log_level='error', drawer_config = { width = 60, side = 'right' } })]]
    child.lua [[require('marker-groups.state').initialize(require('marker-groups.config').get())]]
    local has_drawer =
      child.lua [[local cfg=require('marker-groups.config').get(); return type(cfg.drawer_config)=='table' and type(cfg.drawer_config.width)=='number' and type(cfg.drawer_config.side)=='string']]
    MiniTest.expect.equality(has_drawer, true)
    local has_float = child.lua [[local cfg=require('marker-groups.config').get(); return cfg.float_config ~= nil]]
    MiniTest.expect.equality(has_float, false)
  end)
end

T["drawer width / functions and clamping"] = function()
  with_child(function(child)
    child.lua [[require('marker-groups').setup({ data_dir = vim.fn.tempname() .. '_mg_ui2', log_level='error' })]]
    local width_fn =
      child.lua [[local d=require('marker-groups.ui.drawer'); return type(d.set_drawer_width)=='function' and type(d.get_drawer_width)=='function']]
    MiniTest.expect.equality(width_fn, true)
    child.lua [[local d=require('marker-groups.ui.drawer'); d.set_drawer_width(80)]]
    local width_now = child.lua [[return require('marker-groups.ui.drawer').get_drawer_width()]]
    MiniTest.expect.equality(width_now, 80)
    child.lua [[local d=require('marker-groups.ui.drawer'); d.set_drawer_width(20); d.set_drawer_width(150)]]
    local clamped_low =
      child.lua [[local d=require('marker-groups.ui.drawer'); d.set_drawer_width(20); return d.get_drawer_width() >= 30]]
    local clamped_high =
      child.lua [[local d=require('marker-groups.ui.drawer'); d.set_drawer_width(150); return d.get_drawer_width() <= 120]]
    MiniTest.expect.equality(clamped_low, true)
    MiniTest.expect.equality(clamped_high, true)
  end)
end

T["keymaps / setup loads and no bare <leader>m"] = function()
  with_child(function(child)
    child.lua [[require('marker-groups').setup({ data_dir = vim.fn.tempname() .. '_mg_ui3', log_level='error' })]]
    local loaded = child.lua [[local km=require('marker-groups.keymaps'); local ok,err=pcall(km.setup); return ok]]
    MiniTest.expect.equality(loaded, true)
    local bare =
      child.lua [[for _,m in ipairs(vim.api.nvim_get_keymap('n')) do if m.lhs=='<leader>m' then return true end end; return false]]
    MiniTest.expect.equality(bare, false)
  end)
end

T["commands / drawer width command valid and invalid"] = function()
  with_child(function(child)
    child.lua [[require('marker-groups').setup({ data_dir = vim.fn.tempname() .. '_mg_ui4', log_level='error' })]]
    child.lua [[require('marker-groups.commands').setup()]]
    child.cmd "MarkerGroupsDrawerWidth 90"
    local width = child.lua [[return require('marker-groups.ui.drawer').get_drawer_width()]]
    MiniTest.expect.equality(width, 90)
    local ok = child.lua [[return pcall(vim.cmd, 'MarkerGroupsDrawerWidth invalid')]]
    MiniTest.expect.equality(ok, false)
  end)
end

return T
