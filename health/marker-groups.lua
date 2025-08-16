local M = {}

function M.check()
  local ok, mod = pcall(require, "marker-groups.health")
  if ok and mod and type(mod.check) == "function" then
    mod.check()
  else
    local health = vim.health or require "health"
    local start = health.start or health.report_start
    local errorf = health.error or health.report_error
    start "marker-groups.nvim health check"
    errorf "Failed to load marker-groups.health module"
  end
end

return M


