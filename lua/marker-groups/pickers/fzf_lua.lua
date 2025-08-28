local F = {}

function F.name()
  return "fzf_lua"
end
F.module_name = "fzf-lua"

function F.is_ready()
  return package.loaded["fzf-lua"] ~= nil or vim.fn.exists ":FzfLua" == 2
end

function F.show_groups(opts)
  local fzf = require "fzf-lua"
  local groups = require("marker-groups.state").get_group_names() or {}
  return fzf.fzf_exec(
    groups,
    vim.tbl_deep_extend("force", {
      prompt = "Marker Groups> ",
      actions = {
        ["default"] = function(g)
          local name = (g or {})[1]
          if name then
            require("marker-groups.groups").set_active_group(name)
          end
        end,
      },
    }, opts or {})
  )
end

function F.show_markers(opts)
  local fzf = require "fzf-lua"
  local g = require("marker-groups.state").get_group()
  local items = {}
  for _, m in ipairs(g and g.markers or {}) do
    local r = (m.start_line == m.end_line) and tostring(m.start_line) or (m.start_line .. "-" .. m.end_line)
    table.insert(items, string.format("%s:%s:%s", m.buffer_path, r, m.annotation or ""))
  end
  return fzf.fzf_exec(
    items,
    vim.tbl_deep_extend("force", {
      prompt = "Markers> ",
      actions = {
        ["default"] = function(lines)
          local line = (lines or {})[1]
          if not line then
            return
          end
          local path, range = line:match "^(.-):(%d+%-?%d*):"
          local start = tonumber(range and range:match "^(%d+)")
          if path and start then
            vim.cmd("edit " .. path)
            vim.api.nvim_win_set_cursor(0, { start, 0 })
          end
        end,
      },
    }, opts or {})
  )
end

return F
