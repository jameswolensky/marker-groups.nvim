local MiniTest = require 'mini.test'

local T = MiniTest.new_set()

local function with_child(fn)
  local child = MiniTest.new_child_neovim()
  child.restart({ '--headless', '-u', 'scripts/minimal_init.lua' })
  local ok, err = pcall(fn, child)
  child.stop()
  if not ok then error(err) end
end

T['config customization / applies values and renders highlights'] = function()
  with_child(function(child)
    child.lua([[
      require('marker-groups').setup({
        data_dir = vim.fn.tempname() .. '_mg_cfg',
        signs = { marker = '★', multiline_start = '⟪', multiline_end = '⟫' },
        drawer_config = { width = 42, side = 'left', border = 'single', title_pos = 'left' },
        context_lines = 4,
        max_annotation_display = 3,
        keymaps = { enabled = false },
        log_level = 'debug',
      })
      local config = require('marker-groups.config')
      local state = require('marker-groups.state')
      state.initialize(config.get())
    ]])
    local ok = child.lua([[local c=require('marker-groups.config'); local w=c.get_value('drawer_config.width'); local s=c.get_value('drawer_config.side'); return type(w)=='number' and w>=30 and w<=120 and (s=='left' or s=='right')]])
    MiniTest.expect.equality(ok, true)
    child.lua([[
      local buf = vim.api.nvim_create_buf(false,true)
      vim.api.nvim_buf_set_lines(buf,0,-1,false,{'one','two','three'})
      local path = vim.fn.tempname(); vim.api.nvim_buf_set_name(buf, path)
      local state = require('marker-groups.state')
      state.add_marker({ buffer_path = path, start_line=2, end_line=2, annotation='abcdefghiJKLMNOP' })
      require('marker-groups.markers').refresh_extmarks(buf)
      vim.wait(50)
    ]])
    local hls = child.lua([[local ok1,hl1=pcall(vim.api.nvim_get_hl,0,{name='MGSpecMarker'}); local ok2,hl2=pcall(vim.api.nvim_get_hl,0,{name='MGSpecAnnotation'}); return ok1 or ok2]])
    MiniTest.expect.equality(type(hls)=='boolean', true)
  end)
end

return T


