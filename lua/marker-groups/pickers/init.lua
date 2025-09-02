local M = {}

local logger = require "marker-groups.utils.logger"

-- Priority order when auto-detecting a backend
local PRIORITY_ORDER = { "snacks", "fzf_lua", "mini_pick", "vim_ui" }

-- Cached detection results and current backend
local detected_backends_cache = nil
local current_backend_name = nil

local function is_snacks_available()
  if pcall(require, "snacks.picker") then
    return true
  end
  local ok, snacks = pcall(require, "snacks")
  return ok and snacks and snacks.picker ~= nil
end

local function is_fzf_lua_available()
  local ok, fzf_lua = pcall(require, "fzf-lua")
  if not ok or not fzf_lua then
    return false
  end
  return type(fzf_lua.fzf_exec) == "function"
end

local function is_mini_pick_available()
  local ok, pick = pcall(require, "mini.pick")
  if not ok or not pick then
    return false
  end
  return type(pick.start) == "function"
end

local function is_vim_ui_available()
  return type(vim.ui) == "table" and type(vim.ui.select) == "function"
end

local function detect_available_backends()
  if detected_backends_cache ~= nil then
    return detected_backends_cache
  end

  local backends = {}

  backends.snacks = is_snacks_available()
      and {
        available = true,
        version = "unknown",
        backend = require "marker-groups.pickers.snacks",
      }
    or { available = false, error = "not available" }

  backends.fzf_lua = is_fzf_lua_available()
      and {
        available = true,
        version = "unknown",
        backend = require "marker-groups.pickers.fzf_lua",
      }
    or { available = false, error = "not available" }

  backends.mini_pick = is_mini_pick_available()
      and {
        available = true,
        version = "unknown",
        backend = require "marker-groups.pickers.mini_pick",
      }
    or { available = false, error = "not available" }

  backends.vim_ui = is_vim_ui_available()
      and {
        available = true,
        version = "builtin",
        backend = require "marker-groups.pickers.vim_ui",
      }
    or { available = false, error = "not available" }

  detected_backends_cache = backends
  return backends
end

local function determine_backend(requested)
  local available = detect_available_backends()

  local normalized = requested
  if type(normalized) == "string" then
    if normalized == "vim" then
      normalized = "vim_ui"
    elseif normalized == "fzf-lua" then
      normalized = "fzf_lua"
    elseif normalized == "mini.pick" or normalized == "mini-pick" or normalized == "minipick" then
      normalized = "mini_pick"
    end
  end

  if normalized and normalized ~= "auto" then
    if available[normalized] and available[normalized].available then
      return normalized
    else
      return "vim_ui"
    end
  end

  return "vim_ui"
end

function M.setup(config)
  config = config or {}
  detected_backends_cache = nil
  current_backend_name = determine_backend(config.picker or "vim_ui")

  logger.debug("Picker backend set to: " .. tostring(current_backend_name))
end

function M.get_status()
  local available = detect_available_backends()
  local list = {}
  for name, info in pairs(available) do
    if info.available then
      table.insert(list, name)
    end
  end
  return {
    current_backend = current_backend_name or "vim_ui",
    available_backends = list,
    backends = available,
  }
end

function M.show_picker_status()
  local status = M.get_status()
  local lines = {
    "Marker Groups Picker Status",
    "═══════════════════════════",
    "",
    "Current Backend: " .. (status.current_backend or "none"),
    "",
    "Available Backends:",
  }

  for name, info in pairs(status.backends or {}) do
    local status_icon = info.available and "✅" or "❌"
    local version_info = info.version and (" (v" .. tostring(info.version) .. ")") or ""
    local error_info = info.error and (" - " .. tostring(info.error)) or ""
    table.insert(lines, string.format("  %s %s%s%s", status_icon, name, version_info, error_info))
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  local width = 60
  local height = math.max(8, #lines + 2)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = "Picker Status",
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<cmd>close<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })

  return win
end

function M.show_groups(opts)
  local available = detect_available_backends()
  local name = current_backend_name or "vim_ui"
  local backend = available[name] and available[name].backend
  if not backend and available.vim_ui and available.vim_ui.available then
    backend = require "marker-groups.pickers.vim_ui"
  end
  if backend and backend.show_groups then
    return backend.show_groups(opts)
  end
  vim.notify("No picker backend available", vim.log.levels.ERROR)
end

-- Convenience wrapper to open group picker in deletion mode
function M.delete_groups(opts)
  opts = opts or {}
  opts.action = "delete"
  return M.show_groups(opts)
end

function M.show_markers(opts)
  local available = detect_available_backends()
  local name = current_backend_name or "vim_ui"
  local backend = available[name] and available[name].backend
  if not backend and available.vim_ui and available.vim_ui.available then
    backend = require "marker-groups.pickers.vim_ui"
  end
  if backend and backend.show_markers then
    return backend.show_markers(opts)
  end
  vim.notify("No picker backend available", vim.log.levels.ERROR)
end

return M
