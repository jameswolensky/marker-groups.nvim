---@class MarkerGroupsConfig
---@field data_dir string Path to store marker group data
---@field auto_save boolean Automatically save on state changes
---@field backup_count integer Number of backup files to keep
---@field signs table Visual signs configuration
---@field highlight_groups table Highlight group names
---@field float_config table Floating window configuration
---@field context_lines integer Lines of context around markers
---@field max_annotation_display integer Max characters in virtual text
---@field keymaps table Default keybindings
---@field debug boolean Enable debug mode
---@field log_level string Log level (debug, info, warn, error)

local M = {}

---@type MarkerGroupsConfig|nil
M.options = nil

---Default configuration values
---@type MarkerGroupsConfig
local defaults = {
  -- Persistence
  data_dir = vim.fn.stdpath("data") .. "/marker-groups",
  auto_save = true,
  backup_count = 3,
  
  -- Visual indicators
  signs = {
    marker = "●",
    multiline_start = "┌",
    multiline_end = "└",
  },
  
  highlight_groups = {
    marker = "MarkerGroupsMarker",
    annotation = "MarkerGroupsAnnotation", 
    context = "MarkerGroupsContext",
  },
  
  -- Floating window
  float_config = {
    width = 0.8,        -- Fraction of editor width
    height = 0.8,       -- Fraction of editor height
    border = "rounded",
    title_pos = "center",
  },
  
  -- Context
  context_lines = 2,    -- Lines above/below marker in viewer
  max_annotation_display = 50,  -- Characters in virtual text
  
  -- Keymaps
  keymaps = {
    add_marker = "<leader>ma",
    edit_marker = "<leader>me", 
    delete_marker = "<leader>md",
    view_group = "<leader>mv",
    select_group = "<leader>mg",
    marker_telescope = "<leader>mf",
  },
  
  -- Development
  debug = false,
  log_level = "info",   -- "debug", "info", "warn", "error"
}

---Validate configuration values
---@param config table Configuration to validate
---@return boolean, string? success, error_message
local function validate_config(config)
  -- Validate required string fields
  local string_fields = {
    "data_dir",
    "log_level",
  }
  
  for _, field in ipairs(string_fields) do
    if config[field] and type(config[field]) ~= "string" then
      return false, string.format("config.%s must be a string, got %s", field, type(config[field]))
    end
  end
  
  -- Validate numeric fields
  local numeric_fields = {
    "backup_count",
    "context_lines", 
    "max_annotation_display",
  }
  
  for _, field in ipairs(numeric_fields) do
    if config[field] and type(config[field]) ~= "number" then
      return false, string.format("config.%s must be a number, got %s", field, type(config[field]))
    end
  end
  
  -- Validate boolean fields
  local boolean_fields = {
    "auto_save",
    "debug",
  }
  
  for _, field in ipairs(boolean_fields) do
    if config[field] and type(config[field]) ~= "boolean" then
      return false, string.format("config.%s must be a boolean, got %s", field, type(config[field]))
    end
  end
  
  -- Validate log level
  if config.log_level then
    local valid_levels = { "debug", "info", "warn", "error" }
    local valid = false
    for _, level in ipairs(valid_levels) do
      if config.log_level == level then
        valid = true
        break
      end
    end
    if not valid then
      return false, string.format("config.log_level must be one of: %s", table.concat(valid_levels, ", "))
    end
  end
  
  -- Validate float_config width/height are between 0 and 1
  if config.float_config then
    if config.float_config.width and (config.float_config.width <= 0 or config.float_config.width > 1) then
      return false, "config.float_config.width must be between 0 and 1"
    end
    if config.float_config.height and (config.float_config.height <= 0 or config.float_config.height > 1) then
      return false, "config.float_config.height must be between 0 and 1"
    end
  end
  
  return true, nil
end

---Setup configuration by merging user options with defaults
---@param opts? table User configuration options
---@return MarkerGroupsConfig
function M.setup(opts)
  opts = opts or {}
  
  -- Deep merge user options with defaults
  local config = vim.tbl_deep_extend("force", {}, defaults, opts)
  
  -- Validate the merged configuration
  local valid, error_msg = validate_config(config)
  if not valid then
    error("marker-groups.nvim configuration error: " .. error_msg)
  end
  
  -- Ensure data directory exists
  if not vim.fn.isdirectory(config.data_dir) then
    vim.fn.mkdir(config.data_dir, "p")
  end
  
  M.options = config
  return config
end

---Get current configuration
---@return MarkerGroupsConfig
function M.get()
  if not M.options then
    error("marker-groups.nvim: Configuration not initialized. Call setup() first.")
  end
  return M.options
end

---Get a specific configuration value with optional default
---@param key string Configuration key (supports dot notation)
---@param default? any Default value if key doesn't exist
---@return any
function M.get_value(key, default)
  local config = M.get()
  
  -- Support dot notation (e.g., "float_config.width")
  local keys = vim.split(key, ".", { plain = true })
  local value = config
  
  for _, k in ipairs(keys) do
    if type(value) ~= "table" or value[k] == nil then
      return default
    end
    value = value[k]
  end
  
  return value
end

---Update configuration at runtime
---@param updates table Configuration updates to apply
---@return boolean success
function M.update(updates)
  if not M.options then
    error("marker-groups.nvim: Configuration not initialized. Call setup() first.")
  end
  
  -- Merge updates with current config
  local new_config = vim.tbl_deep_extend("force", {}, M.options, updates)
  
  -- Validate updated configuration
  local valid, error_msg = validate_config(new_config)
  if not valid then
    vim.notify("Configuration update failed: " .. error_msg, vim.log.levels.ERROR)
    return false
  end
  
  M.options = new_config
  
  -- Emit configuration change event
  local state = require("marker-groups.state")
  if state and state.emit then
    state.emit("config_changed", new_config)
  end
  
  return true
end

---Get the default configuration (for reference)
---@return MarkerGroupsConfig
function M.get_defaults()
  return vim.deepcopy(defaults)
end

return M