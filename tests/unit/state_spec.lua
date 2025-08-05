---Unit tests for marker-groups state module
local assert = require('luassert')
local state = require('marker-groups.state')
local config = require('marker-groups.config')

describe('marker-groups state module', function()
  before_each(function()
    -- Reset state for each test
    state.initialize(config.get())
  end)
  
  describe('initialization', function()
    it('should initialize with default state', function()
      local current_state = state.get_state()
      
      assert.is_table(current_state)
      assert.is_table(current_state.marker_groups)
      assert.is_string(current_state.active_group)
      assert.are.equal('default', current_state.active_group)
    end)
    
    it('should have default group', function()
      local groups = state.get_all_groups()
      
      assert.is_table(groups)
      assert.is_not_nil(groups.default)
      assert.is_table(groups.default.markers)
    end)
  end)
  
  describe('group management', function()
    it('should get active group', function()
      local active = state.get_active_group()
      assert.is_string(active)
      assert.are.equal('default', active)
    end)
    
    it('should set active group', function()
      -- Create a new group first
      state.add_group('test-group')
      
      state.set_active_group('test-group')
      local active = state.get_active_group()
      
      assert.are.equal('test-group', active)
    end)
    
    it('should add new groups', function()
      local result = state.add_group('new-group')
      
      assert.is_true(result.success)
      
      local groups = state.get_all_groups()
      assert.is_not_nil(groups['new-group'])
      assert.is_table(groups['new-group'].markers)
    end)
    
    it('should not add duplicate groups', function()
      state.add_group('test-group')
      local result = state.add_group('test-group')
      
      assert.is_false(result.success)
      assert.is_string(result.error)
    end)
    
    it('should remove groups', function()
      state.add_group('removable-group')
      local result = state.remove_group('removable-group')
      
      assert.is_true(result.success)
      
      local groups = state.get_all_groups()
      assert.is_nil(groups['removable-group'])
    end)
    
    it('should not remove default group', function()
      local result = state.remove_group('default')
      
      assert.is_false(result.success)
      assert.is_string(result.error)
    end)
    
    it('should rename groups', function()
      state.add_group('old-name')
      local result = state.rename_group('old-name', 'new-name')
      
      assert.is_true(result.success)
      
      local groups = state.get_all_groups()
      assert.is_nil(groups['old-name'])
      assert.is_not_nil(groups['new-name'])
    end)
  end)
  
  describe('marker management', function()
    local test_marker
    
    before_each(function()
      test_marker = {
        buffer_path = '/test/file.lua',
        start_line = 10,
        end_line = 10,
        annotation = 'Test marker',
        timestamp = os.time()
      }
    end)
    
    it('should add markers to active group', function()
      local result = state.add_marker(test_marker)
      
      assert.is_true(result.success)
      
      local group = state.get_group('default')
      assert.are.equal(1, #group.markers)
      assert.are.equal('Test marker', group.markers[1].annotation)
    end)
    
    it('should add markers to specific group', function()
      state.add_group('target-group')
      local result = state.add_marker(test_marker, 'target-group')
      
      assert.is_true(result.success)
      
      local group = state.get_group('target-group')
      assert.are.equal(1, #group.markers)
    end)
    
    it('should not add invalid markers', function()
      local invalid_marker = { annotation = 'Missing required fields' }
      local result = state.add_marker(invalid_marker)
      
      assert.is_false(result.success)
      assert.is_string(result.error)
    end)
    
    it('should remove markers', function()
      state.add_marker(test_marker)
      local group = state.get_group('default')
      local marker_id = group.markers[1].id
      
      local result = state.remove_marker(marker_id)
      
      assert.is_true(result.success)
      
      local updated_group = state.get_group('default')
      assert.are.equal(0, #updated_group.markers)
    end)
    
    it('should update markers', function()
      state.add_marker(test_marker)
      local group = state.get_group('default')
      local marker_id = group.markers[1].id
      
      local updated_marker = {
        id = marker_id,
        buffer_path = '/test/file.lua',
        start_line = 10,
        end_line = 10,
        annotation = 'Updated annotation',
        timestamp = os.time()
      }
      
      local result = state.update_marker(updated_marker)
      
      assert.is_true(result.success)
      
      local updated_group = state.get_group('default')
      assert.are.equal('Updated annotation', updated_group.markers[1].annotation)
    end)
  end)
  
  describe('event system', function()
    it('should trigger events on state changes', function()
      local event_triggered = false
      local event_data = nil
      
      -- Subscribe to event
      state.subscribe('group_added', function(data)
        event_triggered = true
        event_data = data
      end)
      
      -- Trigger state change
      state.add_group('event-test-group')
      
      -- Check event was triggered
      assert.is_true(event_triggered)
      assert.is_table(event_data)
      assert.are.equal('event-test-group', event_data.group_name)
    end)
    
    it('should unsubscribe from events', function()
      local event_count = 0
      
      local unsubscribe = state.subscribe('group_added', function()
        event_count = event_count + 1
      end)
      
      state.add_group('test1')
      assert.are.equal(1, event_count)
      
      unsubscribe()
      state.add_group('test2')
      assert.are.equal(1, event_count) -- Should not increment
    end)
  end)
  
  describe('state validation', function()
    it('should validate state structure', function()
      local current_state = state.get_state()
      
      -- Check required top-level fields
      assert.is_table(current_state.marker_groups)
      assert.is_string(current_state.active_group)
      assert.is_number(current_state.version)
    end)
    
    it('should validate group structure', function()
      local groups = state.get_all_groups()
      
      for group_name, group_data in pairs(groups) do
        assert.is_string(group_name)
        assert.is_table(group_data)
        assert.is_table(group_data.markers)
        assert.is_number(group_data.created_at)
      end
    end)
  end)
end)