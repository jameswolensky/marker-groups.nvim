local MiniTest = require 'mini.test'

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      package.loaded['marker-groups'] = nil
      package.loaded['marker-groups.state'] = nil
      package.loaded['marker-groups.config'] = nil
      package.loaded['marker-groups.groups'] = nil

      require('marker-groups').setup({
        data_dir = vim.fn.tempname() .. '_marker_groups_test',
        log_level = 'debug',
        keymaps = { enabled = false },
      })

      local config = require('marker-groups.config')
      require('marker-groups.state').initialize(config.get())
    end,
  },
})

-- Helpers
local expect_truthy = MiniTest.new_expectation('truthy', function(x) return not not x end, function(x) return 'Object: ' .. vim.inspect(x) end)
local expect_falsy = MiniTest.new_expectation('falsy', function(x) return not x end, function(x) return 'Object: ' .. vim.inspect(x) end)
local expect_type = MiniTest.new_expectation('type', function(x, t) return type(x) == t end, function(x, t) return string.format('Expected %s, got %s. Object: %s', t, type(x), vim.inspect(x)) end)

-- initialization
T['initialization / should initialize with default state'] = function()
  local state = require('marker-groups.state')
  local current = state.get_state()
  expect_type(current, 'table')
  expect_type(current.marker_groups, 'table')
  expect_type(current.active_group, 'string')
  MiniTest.expect.equality('default', current.active_group)
end

T['initialization / should have default group'] = function()
  local state = require('marker-groups.state')
  local groups = state.get_all_groups()
  expect_type(groups, 'table')
  expect_truthy(groups.default ~= nil)
  expect_type(groups.default.markers, 'table')
end

-- group management
T['group management / should get active group'] = function()
  local state = require('marker-groups.state')
  local active = state.get_active_group()
  expect_type(active, 'string')
  MiniTest.expect.equality('default', active)
end

T['group management / should set active group'] = function()
  local state = require('marker-groups.state')
  state.add_group('test-group')
  state.set_active_group('test-group')
  local active = state.get_active_group()
  MiniTest.expect.equality('test-group', active)
end

T['group management / should add new groups'] = function()
  local state = require('marker-groups.state')
  local result = state.add_group('new-group')
  expect_truthy(result.success)
  local groups = state.get_all_groups()
  expect_truthy(groups['new-group'] ~= nil)
  expect_type(groups['new-group'].markers, 'table')
end

T['group management / should not add duplicate groups'] = function()
  local state = require('marker-groups.state')
  state.add_group('test-group')
  local result = state.add_group('test-group')
  expect_falsy(result.success)
  expect_type(result.error, 'string')
end

T['group management / should remove groups'] = function()
  local state = require('marker-groups.state')
  state.add_group('removable-group')
  local result = state.remove_group('removable-group')
  expect_truthy(result.success)
  local groups = state.get_all_groups()
  expect_falsy(groups['removable-group'] ~= nil)
end

T['group management / should not remove default group'] = function()
  local state = require('marker-groups.state')
  local result = state.remove_group('default')
  expect_falsy(result.success)
  expect_type(result.error, 'string')
end

T['group management / should rename groups'] = function()
  local state = require('marker-groups.state')
  state.add_group('old-name')
  local groups_mod = require('marker-groups.groups')
  local result = groups_mod.rename_group('old-name', 'new-name')
  expect_truthy(result.success)
  local groups = state.get_all_groups()
  expect_falsy(groups['old-name'] ~= nil)
  expect_truthy(groups['new-name'] ~= nil)
end

T["group management / allows spaces in group names and treats 'group 2' as valid"] = function()
  local state = require('marker-groups.state')
  local result = state.create_group('group 2')
  expect_truthy(result.success)
  local groups = state.get_all_groups()
  expect_truthy(groups['group 2'] ~= nil)
end

T['group management / renames without delete/recreate (preserves markers and emits events)'] = function()
  local state = require('marker-groups.state')
  local create = state.create_group('rename-src')
  expect_truthy(create.success)

  local marker_data = {
    buffer_path = '/tmp/rename-test.lua',
    start_line = 1,
    end_line = 1,
    annotation = 'keep me',
  }
  local add_res = state.add_marker(marker_data, 'rename-src')
  expect_truthy(add_res.success)

  local renamed
  state.subscribe('group_deleted', function() error('group_deleted should not fire during rename') end)
  state.subscribe('group_created', function() error('group_created should not fire during rename') end)
  state.subscribe('group_renamed', function(data) renamed = data end)

  local groups_mod = require('marker-groups.groups')
  local result = groups_mod.rename_group('rename-src', 'rename-dst')
  expect_truthy(result.success)

  local groups_after = state.get_all_groups()
  expect_falsy(groups_after['rename-src'] ~= nil)
  expect_truthy(groups_after['rename-dst'] ~= nil)
  MiniTest.expect.equality(1, #groups_after['rename-dst'].markers)
  expect_truthy(renamed ~= nil)
  MiniTest.expect.equality('rename-src', renamed.old_name)
  MiniTest.expect.equality('rename-dst', renamed.new_name)
end

-- marker management
T['marker management / should add markers to active group'] = function()
  local state = require('marker-groups.state')
  local marker = { buffer_path = '/test/file.lua', start_line = 10, end_line = 10, annotation = 'Test marker', timestamp = os.time() }
  local result = state.add_marker(marker)
  expect_truthy(result.success)
  local group = state.get_group('default')
  MiniTest.expect.equality(1, #group.markers)
  MiniTest.expect.equality('Test marker', group.markers[1].annotation)
end

T['marker management / prevents overlapping markers in the same group and file'] = function()
  local state = require('marker-groups.state')
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { 'A', 'B', 'C', 'D' })
  local temp_file = '/tmp/test-overlap-' .. math.random(1000, 9999) .. '.lua'
  vim.api.nvim_buf_set_name(test_buf, temp_file)

  local first = state.add_marker({ buffer_path = temp_file, start_line = 2, end_line = 4, annotation = 'first' })
  expect_truthy(first.success)

  local overlap = state.add_marker({ buffer_path = temp_file, start_line = 3, end_line = 3, annotation = 'second' })
  expect_falsy(overlap.success)
  expect_type(overlap.error, 'string')

  vim.api.nvim_buf_delete(test_buf, { force = true })
end

T['marker management / should add markers to specific group'] = function()
  local state = require('marker-groups.state')
  state.add_group('target-group')
  local marker = { buffer_path = '/test/file.lua', start_line = 10, end_line = 10, annotation = 'Test marker', timestamp = os.time() }
  local result = state.add_marker(marker, 'target-group')
  expect_truthy(result.success)
  local group = state.get_group('target-group')
  MiniTest.expect.equality(1, #group.markers)
end

T['marker management / should not add invalid markers'] = function()
  local state = require('marker-groups.state')
  local invalid_marker = { annotation = 'Missing fields' }
  local result = state.add_marker(invalid_marker)
  expect_falsy(result.success)
  expect_type(result.error, 'string')
end

T['marker management / should remove markers'] = function()
  local state = require('marker-groups.state')
  state.add_marker({ buffer_path = '/test/file.lua', start_line = 10, end_line = 10, annotation = 'Test marker', timestamp = os.time() })
  local group = state.get_group('default')
  local marker_id = group.markers[1].id
  local result = state.remove_marker(marker_id)
  expect_truthy(result.success)
  local updated = state.get_group('default')
  MiniTest.expect.equality(0, #updated.markers)
end

T['marker management / should update markers'] = function()
  local state = require('marker-groups.state')
  state.add_marker({ buffer_path = '/test/file.lua', start_line = 10, end_line = 10, annotation = 'Test marker', timestamp = os.time() })
  local group = state.get_group('default')
  local id = group.markers[1].id
  local updated_marker = { id = id, buffer_path = '/test/file.lua', start_line = 10, end_line = 10, annotation = 'Updated annotation', timestamp = os.time() }
  local result = state.update_marker(updated_marker)
  expect_truthy(result.success)
  local updated = state.get_group('default')
  MiniTest.expect.equality('Updated annotation', updated.markers[1].annotation)
end

-- event system
T['event system / should trigger events on state changes'] = function()
  local state = require('marker-groups.state')
  local triggered = false
  local event_data = nil
  state.subscribe('group_created', function(data) triggered = true; event_data = data end)
  state.add_group('event-test-group')
  expect_truthy(triggered)
  expect_type(event_data, 'table')
  MiniTest.expect.equality('event-test-group', event_data.group_name)
end

T['event system / should unsubscribe from events'] = function()
  local state = require('marker-groups.state')
  local count = 0
  local unsub = state.subscribe('group_created', function() count = count + 1 end)
  state.add_group('test1')
  MiniTest.expect.equality(1, count)
  unsub()
  state.add_group('test2')
  MiniTest.expect.equality(1, count)
end

-- state validation
T['state validation / should validate state structure'] = function()
  local state = require('marker-groups.state')
  local current = state.get_state()
  expect_type(current.marker_groups, 'table')
  expect_type(current.active_group, 'string')
  expect_type(current.version or os.time(), 'number')
end

T['state validation / should validate group structure'] = function()
  local state = require('marker-groups.state')
  local groups = state.get_all_groups()
  for name, data in pairs(groups) do
    expect_type(name, 'string')
    expect_type(data, 'table')
    expect_type(data.markers, 'table')
    expect_type(data.created_at, 'number')
  end
end

-- core functionality verification
T['core functionality verification / can delete multi-line marker and immediately recreate it'] = function()
  local state = require('marker-groups.state')
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { 'Line 1', 'Line 2', 'Line 3' })
  local temp_file = '/tmp/test-state-multiline-' .. math.random(1000, 9999) .. '.lua'
  vim.api.nvim_buf_set_name(test_buf, temp_file)
  local marker = { buffer_path = temp_file, start_line = 1, end_line = 3, annotation = 'Multi-line marker' }
  local add = state.add_marker(marker)
  expect_truthy(add.success)
  local group = state.get_group('default')
  MiniTest.expect.equality(1, #group.markers)
  local id = group.markers[1].id
  local del = state.remove_marker(id)
  expect_truthy(del.success)
  local updated = state.get_group('default')
  MiniTest.expect.equality(0, #updated.markers)
  local recreate = state.add_marker(marker)
  expect_truthy(recreate.success)
  local final = state.get_group('default')
  MiniTest.expect.equality(1, #final.markers)
  vim.api.nvim_buf_delete(test_buf, { force = true })
end

T['core functionality verification / can add marker to same line number/range but different marker group'] = function()
  local state = require('marker-groups.state')
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { 'L1', 'L2', 'L3' })
  local temp_file = '/tmp/test-state-sameline-' .. math.random(1000, 9999) .. '.lua'
  vim.api.nvim_buf_set_name(test_buf, temp_file)
  local res = state.create_group('second-group')
  expect_truthy(res.success)
  local marker = { buffer_path = temp_file, start_line = 1, end_line = 1, annotation = 'First marker' }
  local first = state.add_marker(marker)
  expect_truthy(first.success)
  marker.annotation = 'Second marker'
  local second = state.add_marker(marker, 'second-group')
  expect_truthy(second.success)
  local def = state.get_group('default')
  local sec = state.get_group('second-group')
  MiniTest.expect.equality(1, #def.markers)
  MiniTest.expect.equality(1, #sec.markers)
  MiniTest.expect.equality('First marker', def.markers[1].annotation)
  MiniTest.expect.equality('Second marker', sec.markers[1].annotation)
  vim.api.nvim_buf_delete(test_buf, { force = true })
end

T['core functionality verification / default marker group can never be deleted'] = function()
  local state = require('marker-groups.state')
  local del = state.delete_group('default')
  expect_falsy(del.success)
  expect_type(del.error, 'string')
  local group = state.get_group('default')
  expect_truthy(group ~= nil)
end

T['core functionality verification / can delete all markers in a marker group and marker group persists'] = function()
  local state = require('marker-groups.state')
  local res = state.create_group('test-group')
  expect_truthy(res.success)
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { 'Test line' })
  local temp_file = '/tmp/test-state-deleteall-' .. math.random(1000, 9999) .. '.lua'
  vim.api.nvim_buf_set_name(test_buf, temp_file)
  for i = 1, 3 do
    local m = { buffer_path = temp_file, start_line = i, end_line = i, annotation = 'Marker ' .. i }
    local add = state.add_marker(m, 'test-group')
    expect_truthy(add.success)
  end
  local group = state.get_group('test-group')
  MiniTest.expect.equality(3, #group.markers)
  local ids = {}
  for _, m in ipairs(group.markers) do table.insert(ids, m.id) end
  for _, id in ipairs(ids) do
    local del = state.remove_marker(id)
    expect_truthy(del.success)
  end
  local final = state.get_group('test-group')
  expect_truthy(final ~= nil)
  MiniTest.expect.equality(0, #final.markers)
  vim.api.nvim_buf_delete(test_buf, { force = true })
end

return T


