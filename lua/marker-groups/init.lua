---@class MarkerGroups
---@field setup fun(opts?: table): MarkerGroups
---@field reload fun(): nil
local M = {}

---@type boolean
local _initialized = false

---Setup the marker-groups plugin
---@param opts? table Plugin configuration options
---@return MarkerGroups
function M.setup(opts)
  -- Prevent multiple initialization
  if _initialized then
    return M
  end

  -- Initialize configuration
  local config = require("marker-groups.config").setup(opts)
  
  -- Initialize state management
  require("marker-groups.state").initialize(config)
  
  -- Set up commands
  require("marker-groups.commands").setup()
  
  -- Set up keymaps  
  require("marker-groups.keymaps").setup()
  
  -- Initialize UI components
  local virtual_text = require("marker-groups.ui.virtual_text")
  virtual_text.setup_highlights()
  virtual_text.setup_auto_updates()
  
  -- Initialize floating window system
  local floating = require("marker-groups.ui.floating")
  floating.setup_auto_resize()
  
  -- Initialize logger system
  local logger = require("marker-groups.utils.logger")
  logger.setup()
  logger.register_commands()

  -- Initialize debug utilities
  local debug = require("marker-groups.utils.debug")
  debug.register_commands()

  -- Register health checks
  require("marker-groups.health").register()
  
  -- Load persistence layer
  local persistence = require("marker-groups.persistence")
  persistence.load()
  
  -- Set up auto-save on state changes
  persistence.setup_auto_save()
  
  -- Setup global line tracking for all buffers
  require("marker-groups.markers").setup_global_line_tracking()
  
    _initialized = true
  vim.g.marker_groups_setup_called = true
  logger.info("Marker groups plugin initialized successfully")

  return M
end

---Hot reload the plugin (development only)
---@return nil
function M.reload()
  -- Clear initialized flag
  _initialized = false
  
  -- Clear all marker-groups modules from package.loaded
  for name, _ in pairs(package.loaded) do
    if name:match("^marker%-groups") then
      package.loaded[name] = nil
    end
  end
  
  -- Reinitialize with empty config (will use defaults)
  require("marker-groups").setup({})
  
  vim.notify("marker-groups.nvim reloaded", vim.log.levels.INFO)
end

---Get plugin version info
---@return table
function M.version()
  return {
    name = "marker-groups.nvim",
    version = "1.0.0",
    neovim_version = vim.version(),
  }
end

---Check if plugin is initialized
---@return boolean
function M.is_initialized()
  return _initialized
end

return M