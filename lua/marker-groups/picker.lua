local M = {}

local config = require "marker-groups.config"
local feedback = require "marker-groups.feedback"
local logger = require "marker-groups.utils.logger"

local providers = {}

function M.register(name, adapter)
  providers[name] = adapter
end
-- Report configured provider name
function M.configured()
  return config.get_value("picker.provider", "telescope")
end

-- Whether a named provider is registered and ready (loadable and is_ready())
function M.is_ready(name)
  local p = providers[name]
  if not p then
    return false
  end
  local ok_require = pcall(require, p.module_name or p.name())
  if not ok_require then
    return false
  end
  return p.is_ready and p.is_ready() or false
end

local function resolve_provider()
  local name = config.get_value("picker.provider", "telescope")
  local provider = providers[name]
  if not provider then
    return nil, "Unknown picker provider: " .. tostring(name)
  end
  return provider
end

local function get_call_opts()
  local user_cfg = config.get_value("picker.config", nil)
  if user_cfg == nil then
    return {}
  end
  return vim.deepcopy(user_cfg)
end

local function fallback_native(kind)
  local ok, native = pcall(require, "marker-groups.pickers.native")
  if not ok then
    return feedback.warning("Picker", "Native picker unavailable")
  end
  local call_opts = get_call_opts()
  if kind == "groups" then
    return native.show_groups(call_opts)
  else
    return native.show_markers(call_opts)
  end
end

local function call(kind)
  local provider = resolve_provider()
  if not provider then
    logger.info "Picker: no provider resolved; falling back to native"
    return fallback_native(kind)
  end

  -- Require-only readiness check
  local ok_require = pcall(require, provider.module_name or provider.name())
  if not ok_require or not provider.is_ready() then
    local configured = config.get_value("picker.provider", "telescope")
    logger.info(
      string.format(
        "Picker: provider '%s' not ready (configured: '%s'); using native fallback",
        provider.name and provider.name() or tostring(provider),
        tostring(configured)
      )
    )
    return fallback_native(kind)
  end

  local call_opts = get_call_opts()

  local ok, err_or_result
  logger.info(
    string.format("Picker: invoking provider '%s' for %s", provider.name and provider.name() or "unknown", kind)
  )
  if kind == "groups" then
    ok, err_or_result = pcall(provider.show_groups, call_opts)
  else
    ok, err_or_result = pcall(provider.show_markers, call_opts)
  end

  if not ok then
    feedback.warning("Picker", "Provider failed, falling back: " .. tostring(err_or_result))
    return fallback_native(kind)
  end

  return err_or_result
end

function M.show_groups()
  return call "groups"
end

function M.show_markers()
  return call "markers"
end

return M
