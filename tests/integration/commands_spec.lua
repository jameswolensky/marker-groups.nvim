---Integration tests for marker-groups commands
local assert = require('luassert')
local state = require('marker-groups.state')
local config = require('marker-groups.config')

describe('marker-groups command integration', function()
  before_each(function()
    -- Reset state and ensure commands are loaded
    state.initialize(config.get())
    require('marker-groups.commands').setup()
  end)
  
  describe('group management commands', function()
    it('should execute MarkerGroupsCreate command', function()
      local initial_groups = vim.tbl_count(state.get_all_groups())
      
      -- Execute command
      vim.cmd('MarkerGroupsCreate test-group-cmd')
      
      local final_groups = vim.tbl_count(state.get_all_groups())
      assert.are.equal(initial_groups + 1, final_groups)
      
      local group = state.get_group('test-group-cmd')
      assert.is_not_nil(group)
    end)
    
    it('should execute MarkerGroupsSelect command', function()
      -- Create a group first
      state.add_group('selectable-group')
      
      -- Execute command
      vim.cmd('MarkerGroupsSelect selectable-group')
      
      local active_group = state.get_active_group()
      assert.are.equal('selectable-group', active_group)
    end)
    
    it('should execute MarkerGroupsList command', function()
      -- This should not error
      assert.has_no.errors(function()
        vim.cmd('MarkerGroupsList')
      end)
    end)
    
    it('should execute MarkerGroupsRename command', function()
      state.add_group('renamable-group')
      
      vim.cmd('MarkerGroupsRename renamable-group renamed-group')
      
      local groups = state.get_all_groups()
      assert.is_nil(groups['renamable-group'])
      assert.is_not_nil(groups['renamed-group'])
    end)
    
    it('should execute MarkerGroupsDelete command', function()
      state.add_group('deletable-group')
      
      vim.cmd('MarkerGroupsDelete deletable-group')
      
      local groups = state.get_all_groups()
      assert.is_nil(groups['deletable-group'])
    end)
  end)
  
  describe('debug commands', function()
    it('should execute MarkerGroupsDebugMode command', function()
      -- Should not error
      assert.has_no.errors(function()
        vim.cmd('MarkerGroupsDebugMode on')
      end)
      
      assert.has_no.errors(function()
        vim.cmd('MarkerGroupsDebugMode off')
      end)
    end)
    
    it('should execute MarkerGroupsDebugState command', function()
      assert.has_no.errors(function()
        vim.cmd('MarkerGroupsDebugState')
      end)
    end)
    
    it('should execute MarkerGroupsDebugValidate command', function()
      assert.has_no.errors(function()
        vim.cmd('MarkerGroupsDebugValidate')
      end)
    end)
  end)
  
  describe('logger commands', function()
    it('should execute MarkerGroupsLogLevel command', function()
      assert.has_no.errors(function()
        vim.cmd('MarkerGroupsLogLevel debug')
      end)
      
      local logger = require('marker-groups.utils.logger')
      assert.are.equal('debug', logger.get_level())
    end)
    
    it('should execute MarkerGroupsShowLogs command', function()
      assert.has_no.errors(function()
        vim.cmd('MarkerGroupsShowLogs')
      end)
    end)
    
    it('should execute MarkerGroupsClearLogs command', function()
      assert.has_no.errors(function()
        vim.cmd('MarkerGroupsClearLogs')
      end)
    end)
    
    it('should execute MarkerGroupsLogStatus command', function()
      assert.has_no.errors(function()
        vim.cmd('MarkerGroupsLogStatus')
      end)
    end)
  end)
  
  describe('health and maintenance commands', function()
    it('should execute MarkerGroupsHealth command', function()
      -- Register health check
      require('marker-groups.health').register()
      
      assert.has_no.errors(function()
        vim.cmd('MarkerGroupsHealth')
      end)
    end)
    
    it('should execute MarkerGroupsReload command', function()
      assert.has_no.errors(function()
        vim.cmd('MarkerGroupsReload')
      end)
    end)
  end)
  
  describe('telescope commands', function()
    it('should execute MarkerGroupsTelescopeStatus command', function()
      assert.has_no.errors(function()
        vim.cmd('MarkerGroupsTelescopeStatus')
      end)
    end)
    
    -- Note: Actual telescope commands would require telescope to be installed
    -- and would need more complex setup to test properly
  end)
  
  describe('command error handling', function()
    it('should handle invalid group names gracefully', function()
      -- These should not crash Neovim but should show error messages
      assert.has_no.errors(function()
        vim.cmd('MarkerGroupsSelect nonexistent-group')
      end)
      
      assert.has_no.errors(function()
        vim.cmd('MarkerGroupsDelete nonexistent-group')
      end)
      
      assert.has_no.errors(function()
        vim.cmd('MarkerGroupsRename nonexistent old-name')
      end)
    end)
    
    it('should handle invalid arguments gracefully', function()
      assert.has_no.errors(function()
        vim.cmd('MarkerGroupsLogLevel invalid-level')
      end)
      
      assert.has_no.errors(function()
        vim.cmd('MarkerGroupsDebugMode invalid-option')
      end)
    end)
  end)
end)