local M = {}

local logger = require "marker-groups.utils.logger"
function M._is_visual_mode(mode)
  if mode == nil then
    return false
  end

  if mode == "\22" then
    return true
  end

  if type(mode) ~= "string" then
    return false
  end

  local upper = string.upper(mode)
  return upper == "V" or upper == "<C-V>" or upper == "CTRL-V" or upper == "\22"
end

function M.make_range()
  local mode = vim.fn.mode()
  local msg = "|line_selection.make_range| mode: " .. vim.inspect(mode)
  logger.debug(msg)

  local l1, l2

  if M._is_visual_mode(mode) then
    vim.cmd [[execute "normal! \<ESC>"]]
    local sp = vim.fn.getpos "'<"
    local ep = vim.fn.getpos "'>"
    l1 = tonumber(sp[2]) or 1
    l2 = tonumber(ep[2]) or l1
  else
    local cur = vim.fn.getcurpos()
    l1 = tonumber(cur[2]) or 1
    l2 = l1
  end

  local lstart = math.min(l1, l2)
  local lend = math.max(l1, l2)

  return { lstart = lstart, lend = lend }
end

function M.is_range(r)
  return type(r) == "table" and type(r.lstart) == "number" and r.lstart >= 0 and type(r.lend) == "number" and r.lend > 0
end

return M
