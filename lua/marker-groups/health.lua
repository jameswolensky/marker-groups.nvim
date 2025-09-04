local M = {}

function M.check()
  local health = vim.health or require "health"
  local start = health.start or health.report_start
  local ok = health.ok or health.report_ok
  local warn = health.warn or health.report_warn
  local error = health.error or health.report_error

  start "marker-groups.nvim health check"

  if vim.fn.has "nvim-0.8" == 1 then
    ok "Neovim version is >= 0.8.0"
  else
    error "Neovim >= 0.8.0 required"
  end

  if vim.api.nvim_buf_set_extmark then
    ok "nvim_buf_set_extmark available"
  else
    error "nvim_buf_set_extmark not available"
  end

  if vim.api.nvim_open_win then
    ok "nvim_open_win available"
  else
    error "nvim_open_win not available"
  end

  local marker_groups = require "marker-groups"
  if marker_groups.is_initialized() then
    ok "Plugin is initialized"

    local version_info = marker_groups.version()
    ok(string.format("Plugin version: %s", version_info.version))
  else
    warn "Plugin not initialized - run :lua require('marker-groups').setup()"
  end

  local config = require "marker-groups.config"
  if config.options then
    local data_dir = config.get_value "data_dir"
    if vim.fn.isdirectory(data_dir) == 1 then
      ok("Data directory exists: " .. data_dir)

      local test_file = data_dir .. "/.test_write"
      local success = pcall(function()
        local file = io.open(test_file, "w")
        if file then
          file:write "test"
          file:close()
          os.remove(test_file)
          return true
        end
        return false
      end)

      if success then
        ok "Data directory is writable"
      else
        error("Data directory is not writable: " .. data_dir)
      end
    else
      warn("Data directory not found: " .. data_dir)
    end

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
    error "Configuration not loaded"
  end

  if vim.json then
    ok "JSON support available"
  else
    error "JSON support not available"
  end

  start "Performance checks"
  local start_time = vim.loop.hrtime()

  for i = 1, 100 do
    config.get_value "data_dir"
  end

  local end_time = vim.loop.hrtime()
  local duration_ms = (end_time - start_time) / 1000000

  if duration_ms < 10 then
    ok(string.format("Configuration access is fast: %.2fms", duration_ms))
  else
    warn(string.format("Configuration access is slow: %.2fms", duration_ms))
  end
end

function M.register()
  vim.api.nvim_create_user_command("MarkerGroupsHealth", function()
    local ok = pcall(vim.cmd, "checkhealth marker-groups")
    if not ok then
      M.check()
      require("marker-groups.feedback").notify(
        "Health report generated. View it with :checkhealth marker-groups",
        vim.log.levels.INFO,
        {}
      )
    end
  end, {
    desc = "Run marker-groups health check",
  })
end

return M
