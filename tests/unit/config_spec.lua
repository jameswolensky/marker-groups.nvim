---Unit tests for marker-groups config module
local assert = require('luassert')
local config = require('marker-groups.config')

describe('marker-groups config module', function()
  local original_config
  
  before_each(function()
    -- Save original config
    original_config = vim.deepcopy(config.get())
  end)
  
  after_each(function()
    -- Restore original config
    config.update(original_config)
  end)
  
  describe('get and set operations', function()
    it('should get default values', function()
      local data_dir = config.get_value('data_dir')
      assert.is_string(data_dir)
      assert.is_true(string.len(data_dir) > 0)
    end)
    
    it('should get nested values', function()
      local keymaps_enabled = config.get_value('keymaps.enabled', true)
      assert.is_boolean(keymaps_enabled)
    end)
    
    it('should return default for non-existent keys', function()
      local value = config.get_value('non_existent_key', 'default_value')
      assert.are.equal('default_value', value)
    end)
    
    it('should get full config object', function()
      local full_config = config.get()
      assert.is_table(full_config)
      assert.is_not_nil(full_config.data_dir)
    end)
  end)
  
  describe('configuration updates', function()
    it('should update configuration values', function()
      local new_config = vim.deepcopy(config.get())
      new_config.log_level = 'debug'
      
      config.update(new_config)
      
      local updated_level = config.get_value('log_level')
      assert.are.equal('debug', updated_level)
    end)
    
    it('should preserve existing values when updating', function()
      local original_data_dir = config.get_value('data_dir')
      
      local partial_config = { log_level = 'error' }
      config.update(partial_config)
      
      local updated_data_dir = config.get_value('data_dir')
      assert.are.equal(original_data_dir, updated_data_dir)
    end)
  end)
  
  describe('validation', function()
    it('should validate log levels', function()
      local valid_levels = { 'debug', 'info', 'warn', 'error' }
      
      for _, level in ipairs(valid_levels) do
        local new_config = vim.deepcopy(config.get())
        new_config.log_level = level
        
        -- Should not throw error
        config.update(new_config)
        assert.are.equal(level, config.get_value('log_level'))
      end
    end)
    
    it('should handle boolean values correctly', function()
      local new_config = vim.deepcopy(config.get())
      new_config.auto_save = false
      
      config.update(new_config)
      
      local auto_save = config.get_value('auto_save')
      assert.is_false(auto_save)
    end)
  end)
  
  describe('path handling', function()
    it('should expand data directory path', function()
      local data_dir = config.get_value('data_dir')
      
      -- Should not contain unexpanded vim variables
      assert.is_false(string.match(data_dir, '%%'))
      assert.is_false(string.match(data_dir, '$'))
      
      -- Should be an absolute path
      assert.is_true(vim.fn.fnamemodify(data_dir, ':p') == data_dir)
    end)
  end)
end)