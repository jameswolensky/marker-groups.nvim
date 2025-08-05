-- marker-groups.nvim plugin entry point
-- This file is automatically loaded by Neovim when the plugin is installed

if vim.g.loaded_marker_groups then
  return
end
vim.g.loaded_marker_groups = 1

-- Ensure we have the required Neovim version
if vim.fn.has('nvim-0.8.0') ~= 1 then
  vim.api.nvim_err_writeln('marker-groups.nvim requires Neovim 0.8.0 or higher')
  return
end

-- Create the main plugin command for lazy loading
vim.api.nvim_create_user_command('MarkerGroupsSetup', function(opts)
  require('marker-groups').setup(opts.args and vim.json.decode(opts.args) or {})
end, {
  nargs = '?',
  desc = 'Setup marker-groups.nvim plugin'
})

-- Auto-setup with defaults if called without explicit setup
vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  callback = function()
    -- Only auto-setup if no manual setup has been called
    if not vim.g.marker_groups_setup_called then
      require('marker-groups').setup()
    end
  end,
})

-- Expose version info
vim.g.marker_groups_version = '1.0.0'