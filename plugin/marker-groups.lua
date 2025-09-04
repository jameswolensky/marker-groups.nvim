
if vim.g.loaded_marker_groups then
  return
end
vim.g.loaded_marker_groups = 1

if vim.fn.has('nvim-0.8.0') ~= 1 then
  vim.api.nvim_err_writeln('marker-groups.nvim requires Neovim 0.8.0 or higher')
  return
end

vim.api.nvim_create_user_command('MarkerGroupsSetup', function(opts)
  require('marker-groups').setup(opts.args and vim.json.decode(opts.args) or {})
end, {
  nargs = '?',
  desc = 'Setup marker-groups.nvim plugin'
})

vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  callback = function()
    if vim.g.__mg_minimal_init == true then
      return
    end
    if not vim.g.marker_groups_setup_called then
      require('marker-groups').setup()
    end
  end,
})
