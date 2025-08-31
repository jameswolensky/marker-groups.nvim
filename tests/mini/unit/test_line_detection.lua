local MiniTest = require 'mini.test'

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      package.loaded['marker-groups'] = nil
      package.loaded['marker-groups.markers'] = nil
      package.loaded['marker-groups.state'] = nil
      package.loaded['marker-groups.config'] = nil
      require('marker-groups').setup({ data_dir = vim.fn.tempname() .. '_mg_ld', log_level = 'debug', keymaps = { enabled = false } })
      local config = require('marker-groups.config')
      require('marker-groups.state').initialize(config.get())
    end,
    post_case = function()
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf):match('/tmp/test%-line%-detection%-') then
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
      end
    end,
  },
})

local expect_truthy = MiniTest.new_expectation('truthy', function(x) return not not x end, function(x) return 'Object: ' .. vim.inspect(x) end)

local function setup_buffer(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local temp_file = '/tmp/test-line-detection-' .. math.random(1000, 9999) .. '.lua'
  vim.api.nvim_buf_set_name(buf, temp_file)
  vim.api.nvim_set_current_buf(buf)
  return buf, temp_file
end

T['detects single-line by explicit range'] = function()
  local markers = require('marker-groups.markers')
  local state = require('marker-groups.state')
  setup_buffer({ 'A', 'B', 'C', 'D', 'E' })
  local res = markers.add_marker_range(3, 3, 'single-visual')
  expect_truthy(res.success)
  local group = state.get_group('default')
  MiniTest.expect.equality(1, #group.markers)
  MiniTest.expect.equality(3, group.markers[1].start_line)
  MiniTest.expect.equality(3, group.markers[1].end_line)
end

T['detects multi-line by explicit range'] = function()
  local markers = require('marker-groups.markers')
  local state = require('marker-groups.state')
  setup_buffer({ 'A', 'B', 'C', 'D', 'E' })
  local res = markers.add_marker_range(2, 4, 'visual-multi')
  expect_truthy(res.success)
  local group = state.get_group('default')
  MiniTest.expect.equality(1, #group.markers)
  MiniTest.expect.equality(2, group.markers[1].start_line)
  MiniTest.expect.equality(4, group.markers[1].end_line)
end

T['adds multiple explicit ranges consecutively (latest range respected)'] = function()
  local markers = require('marker-groups.markers')
  local state = require('marker-groups.state')
  setup_buffer({ 'A', 'B', 'C', 'D', 'E' })
  local r1 = markers.add_marker_range(1, 1, 'first')
  expect_truthy(r1.success)
  local r2 = markers.add_marker_range(3, 5, 'second')
  expect_truthy(r2.success)
  local group = state.get_group('default')
  MiniTest.expect.equality(2, #group.markers)
  MiniTest.expect.equality(3, group.markers[2].start_line)
  MiniTest.expect.equality(5, group.markers[2].end_line)
end

T['charwise-like explicit range spans full lines'] = function()
  local markers = require('marker-groups.markers')
  local state = require('marker-groups.state')
  setup_buffer({ 'A', 'B', 'C', 'D', 'E' })
  local r = markers.add_marker_range(3, 4, 'visual-char')
  expect_truthy(r.success)
  local group = state.get_group('default')
  MiniTest.expect.equality(1, #group.markers)
  MiniTest.expect.equality(3, group.markers[1].start_line)
  MiniTest.expect.equality(4, group.markers[1].end_line)
end

T['reversed explicit range is normalized'] = function()
  local markers = require('marker-groups.markers')
  local state = require('marker-groups.state')
  setup_buffer({ 'A', 'B', 'C', 'D', 'E' })
  local res = markers.add_marker_range(4, 2, 'visual-reversed')
  expect_truthy(res.success)
  local group = state.get_group('default')
  MiniTest.expect.equality(1, #group.markers)
  MiniTest.expect.equality(2, group.markers[1].start_line)
  MiniTest.expect.equality(4, group.markers[1].end_line)
end

T['consecutive explicit ranges use the latest selection range'] = function()
  local markers = require('marker-groups.markers')
  local state = require('marker-groups.state')
  setup_buffer({ 'A', 'B', 'C', 'D', 'E', 'F' })
  local r1 = markers.add_marker_range(1, 2, 'first-visual')
  expect_truthy(r1.success)
  local r2 = markers.add_marker_range(4, 5, 'second-visual')
  expect_truthy(r2.success)
  local group = state.get_group('default')
  MiniTest.expect.equality(2, #group.markers)
  MiniTest.expect.equality(1, group.markers[1].start_line)
  MiniTest.expect.equality(2, group.markers[1].end_line)
  MiniTest.expect.equality(4, group.markers[2].start_line)
  MiniTest.expect.equality(5, group.markers[2].end_line)
end

T['explicit single-line results in single-line marker'] = function()
  local markers = require('marker-groups.markers')
  local state = require('marker-groups.state')
  setup_buffer({ 'A', 'B', 'C' })
  local res = markers.add_marker_range(2, 2, 'visual-single')
  expect_truthy(res.success)
  local group = state.get_group('default')
  MiniTest.expect.equality(1, #group.markers)
  MiniTest.expect.equality(2, group.markers[1].start_line)
  MiniTest.expect.equality(2, group.markers[1].end_line)
end

return T


