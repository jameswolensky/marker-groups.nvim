---@class MarkerGroupsHealth
local M = {}

---Perform health check
function M.check()
  -- Support both old and new health check APIs
  local health = vim.health or require("health")
  local start = health.start or health.report_start
  local ok = health.ok or health.report_ok
  local warn = health.warn or health.report_warn
  local error = health.error or health.report_error

  start("marker-groups.nvim health check")

  -- Check Neovim version
  if vim.fn.has("nvim-0.8") == 1 then
    ok("Neovim version is >= 0.8.0")
  else
    error("Neovim >= 0.8.0 required")
  end

  -- Check for required APIs
  if vim.api.nvim_buf_set_extmark then
    ok("nvim_buf_set_extmark available")
  else
    error("nvim_buf_set_extmark not available")
  end

  if vim.api.nvim_open_win then
    ok("nvim_open_win available")
  else
    error("nvim_open_win not available")
  end

  -- Check for optional dependencies
  if pcall(require, "telescope") then
    ok("Telescope is available")
  else
    warn("Telescope not found (optional)")
  end

  -- Check plugin initialization
  local marker_groups = require("marker-groups")
  if marker_groups.is_initialized() then
    ok("Plugin is initialized")
    
    -- Check plugin version
    local version_info = marker_groups.version()
    ok(string.format("Plugin version: %s", version_info.version))
  else
    warn("Plugin not initialized - run :lua require('marker-groups').setup()")
  end

  -- Check data directory and permissions
  local config = require("marker-groups.config")
  if config.options then
    local data_dir = config.get_value("data_dir")
    if vim.fn.isdirectory(data_dir) == 1 then
      ok("Data directory exists: " .. data_dir)
      
      -- Check write permissions
      local test_file = data_dir .. "/.test_write"
      local success = pcall(function()
        local file = io.open(test_file, "w")
        if file then
          file:write("test")
          file:close()
          os.remove(test_file)
          return true
        end
        return false
      end)
      
      if success then
        ok("Data directory is writable")
      else
        error("Data directory is not writable: " .. data_dir)
      end
    else
      warn("Data directory not found: " .. data_dir)
    end
    
    -- Check configuration validity
    local log_level = config.get_value("log_level", "info")
    local valid_levels = { "debug", "info", "warn", "error" }
    local valid_log_level = false
    for _, level in ipairs(valid_levels) do
      if log_level == level then
        valid_log_level = true
        break
      end
    end
    
    if valid_log_level then
      ok("Log level is valid: " .. log_level)
    else
      error("Invalid log level: " .. log_level)
    end
  else
    error("Configuration not loaded")
  end

  -- Check JSON support (for persistence)
  if vim.json then
    ok("JSON support available")
  else
    error("JSON support not available")
  end

  -- Performance check
  start("Performance checks")
  local start_time = vim.loop.hrtime()
  
  -- Simulate some plugin operations
  for i = 1, 100 do
    config.get_value("data_dir")
  end
  
  local end_time = vim.loop.hrtime()
  local duration_ms = (end_time - start_time) / 1000000
  
  if duration_ms < 10 then
    ok(string.format("Configuration access is fast: %.2fms", duration_ms))
  else
    warn(string.format("Configuration access is slow: %.2fms", duration_ms))
  end
end

---Register health check command
function M.register()
  vim.api.nvim_create_user_command("MarkerGroupsHealth", M.check, {
    desc = "Run marker-groups health check"
  })
end

return M