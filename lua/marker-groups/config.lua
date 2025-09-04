local M = {}

M.options = nil

local INTERNAL = {
  max_group_name_chars = 100,
  max_annotation_chars = 100,
}

local defaults = {
  data_dir = vim.fn.stdpath "data" .. "/marker-groups",

  signs = {
    marker = "●",
    multiline_start = "┌",
    multiline_end = "└",
  },

  highlight_groups = {
    marker = "MarkerGroupsMarker",
    annotation = "MarkerGroupsAnnotation",
    context = "MarkerGroupsContext",
    multiline_start = "MarkerGroupsMultilineStart",
    multiline_end = "MarkerGroupsMultilineEnd",
  },

  drawer_config = {
    width = 60,
    side = "right",
    border = "rounded",
    title_pos = "center",
  },

  context_lines = 2,
  max_annotation_display = 50,

  keymaps = {
    enabled = true,
    prefix = "<leader>m",
    mappings = {
      marker = {
        add = { suffix = "a", mode = { "n", "v" }, desc = "Add marker" },
        edit = { suffix = "e", desc = "Edit marker at cursor" },
        delete = { suffix = "d", desc = "Delete marker at cursor" },
        list = { suffix = "l", desc = "List markers in buffer" },
        info = { suffix = "i", desc = "Show marker at cursor" },
      },

      group = {
        create = { suffix = "gc", desc = "Create marker group" },
        select = { suffix = "gs", desc = "Select marker group" },
        list = { suffix = "gl", desc = "List marker groups" },
        rename = { suffix = "gr", desc = "Rename marker group" },
        delete = { suffix = "gd", desc = "Delete marker group" },
        info = { suffix = "gi", desc = "Show active group info" },
        from_branch = { suffix = "gb", desc = "Create group from git branch" },
      },

      persistence = false,

      view = {
        toggle = { suffix = "v", desc = "Toggle drawer marker viewer" },
      },
    },
  },

  debug = false,
  log_level = "info",
}

local function validate_config(config)
  local string_fields = {
    "data_dir",
    "log_level",
  }

  for _, field in ipairs(string_fields) do
    if config[field] and type(config[field]) ~= "string" then
      return false, string.format("config.%s must be a string, got %s", field, type(config[field]))
    end
  end

  local numeric_fields = {
    "context_lines",
    "max_annotation_display",
  }

  for _, field in ipairs(numeric_fields) do
    if config[field] and type(config[field]) ~= "number" then
      return false, string.format("config.%s must be a number, got %s", field, type(config[field]))
    end
  end

  local boolean_fields = {
    "debug",
  }

  for _, field in ipairs(boolean_fields) do
    if config[field] and type(config[field]) ~= "boolean" then
      return false, string.format("config.%s must be a boolean, got %s", field, type(config[field]))
    end
  end

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

  if config.drawer_config then
    if
      config.drawer_config.width
      and (
        type(config.drawer_config.width) ~= "number"
        or config.drawer_config.width < 30
        or config.drawer_config.width > 120
      )
    then
      return false, "config.drawer_config.width must be a number between 30 and 120"
    end
    if config.drawer_config.side and config.drawer_config.side ~= "left" and config.drawer_config.side ~= "right" then
      return false, "config.drawer_config.side must be 'left' or 'right'"
    end
  end

  return true, nil
end

function M.setup(opts)
  opts = opts or {}

  local config = vim.tbl_deep_extend("force", {}, defaults, opts)

  local valid, error_msg = validate_config(config)
  if not valid then
    error("marker-groups.nvim configuration error: " .. error_msg)
  end

  if not vim.fn.isdirectory(config.data_dir) then
    vim.fn.mkdir(config.data_dir, "p")
  end

  M.options = config
  return config
end

function M.get()
  if not M.options then
    error "marker-groups.nvim: Configuration not initialized. Call setup() first."
  end
  return M.options
end

function M.get_value(key, default)
  local config = M.get()

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

function M.get_internal(key)
  return INTERNAL[key]
end

function M.update(updates)
  if not M.options then
    error "marker-groups.nvim: Configuration not initialized. Call setup() first."
  end

  local new_config = vim.tbl_deep_extend("force", {}, M.options, updates)

  local valid, error_msg = validate_config(new_config)
  if not valid then
    require("marker-groups.feedback").notify("Configuration update failed: " .. error_msg, vim.log.levels.ERROR, {})
    return false
  end

  M.options = new_config

  local state = require "marker-groups.state"
  if state and state.emit then
    state.emit("config_changed", new_config)
  end

  return true
end

function M.get_defaults()
  return vim.deepcopy(defaults)
end

return M
