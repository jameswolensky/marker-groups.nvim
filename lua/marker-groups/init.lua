local M = {}

local _initialized = false

function M.setup(opts)
  if _initialized then
    return M
  end

  local config = require("marker-groups.config").setup(opts)

  pcall(function()
    require("marker-groups.pickers").setup(config)
  end)

  require("marker-groups.state").initialize(config)

  require("marker-groups.commands").setup()

  require("marker-groups.keymaps").setup()

  local virtual_text = require "marker-groups.ui.virtual_text"
  virtual_text.setup_highlights()
  virtual_text.setup_auto_updates()

  local drawer = require "marker-groups.ui.drawer"
  drawer.setup_auto_resize()

  local logger = require "marker-groups.utils.logger"
  logger.setup()

  local debug = require "marker-groups.utils.debug"

  require("marker-groups.health").register()

  local persistence = require "marker-groups.persistence"
  persistence.load()

  persistence.setup_auto_save()

  require("marker-groups.markers").setup_global_line_tracking()

  _initialized = true
  vim.g.marker_groups_setup_called = true

  return M
end

function M.reload()
  _initialized = false

  local current_config = nil
  pcall(function()
    current_config = require("marker-groups.config").get()
  end)

  for name, _ in pairs(package.loaded) do
    if name:match "^marker%-groups" then
      package.loaded[name] = nil
    end
  end

  require("marker-groups").setup(current_config or {})
end

function M.version()
  local versions = require "marker-groups.version"
  return {
    name = "marker-groups.nvim",
    version = versions.plugin_version,
    neovim_version = vim.version(),
  }
end

function M.is_initialized()
  return _initialized
end

return M
