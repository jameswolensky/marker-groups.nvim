local nvim_runtime = vim.fn.expand "$VIMRUNTIME"
vim.opt.runtimepath = "." .. "," .. nvim_runtime

local plenary_path = vim.fn.expand "~/.local/share/nvim/site/pack/testing/start/plenary.nvim"
if vim.fn.isdirectory(plenary_path) == 1 then
  vim.opt.runtimepath:append(plenary_path)
else
  plenary_path = vim.fn.expand "~/.local/share/nvim/lazy/plenary.nvim"
  if vim.fn.isdirectory(plenary_path) == 1 then
    vim.opt.runtimepath:append(plenary_path)
  end
end

for k, _ in pairs(package.loaded) do
  if k:match "^marker%-groups" then
    package.loaded[k] = nil
  end
end

vim.cmd("cd " .. vim.fn.getcwd())

pcall(require, "plenary")

vim.api.nvim_create_user_command("PlenaryBustedDirectory", function(opts)
  local busted = require "plenary.busted"
  local directory = opts.args or "tests"

  local spec_files = vim.fn.glob(directory .. "/**/*_spec.lua", false, true)

  for _, file in ipairs(spec_files) do
    busted.run(file)
  end
end, { nargs = "?" })

vim.api.nvim_create_user_command("PlenaryBustedFile", function(opts)
  local busted = require "plenary.busted"
  busted.run(opts.args)
end, { nargs = 1 })

print "Minimal test environment initialized"
print("Runtime path: " .. vim.inspect(vim.opt.runtimepath:get()))

-- Global non-interactive stubs to prevent any prompts in headless CI
vim.o.more = false
vim.ui = vim.ui or {}
vim.ui.input = function(opts, cb)
  if cb then
    cb ""
  end
end
vim.ui.select = function(items, opts, cb)
  if cb then
    cb ""
  end
end

-- Ensure marker-groups' input helper will never block by default
