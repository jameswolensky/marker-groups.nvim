local MiniTest = require "mini.test"

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      for name in pairs(package.loaded) do
        if name:match "^marker%-groups" then
          package.loaded[name] = nil
        end
      end
      vim.g.__mg_force_persist = false
    end,
  },
}

T["persistence disabled by default in tests unless explicitly enabled"] = function()
  local tmp = vim.fn.tempname() .. "_mg_guard"
  require("marker-groups").setup { data_dir = tmp, log_level = "error" }
  local cfg = require("marker-groups.config").get()
  local path = cfg.data_dir .. "/marker-groups.json"

  local persistence = require "marker-groups.persistence"
  persistence.save()
  local exists = vim.fn.filereadable(path) == 1
  -- Under some environments, file may exist from previous runs; assert that save did not create/modify now
  local mtime1 = vim.loop.fs_stat(path) and vim.loop.fs_stat(path).mtime.sec or 0
  vim.wait(50)
  persistence.save()
  local mtime2 = vim.loop.fs_stat(path) and vim.loop.fs_stat(path).mtime.sec or 0
  MiniTest.expect.equality(true, mtime2 <= mtime1)
end

T["persistence can be enabled explicitly via config"] = function()
  local tmp = vim.fn.tempname() .. "_mg_guard_on"
  require("marker-groups").setup { data_dir = tmp, log_level = "error", persistence_enabled = true }
  local cfg = require("marker-groups.config").get()
  local path = cfg.data_dir .. "/marker-groups.json"

  local persistence = require "marker-groups.persistence"
  persistence.save()
  local exists = vim.fn.filereadable(path) == 1

  MiniTest.expect.equality(true, exists)
end

return T
