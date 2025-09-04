## Picker backends

Marker Groups supports multiple picker backends (strict selection with fallback to vim):

- mini.pick (from mini.nvim)
- Snacks.nvim (previews; native close behavior)
- Telescope.nvim (previews; buffer previewer)
- fzf-lua (previews; ESC aborts)
- vim.ui.select (basic, always available)

### Behavior

- Group lists: Enter deletes the selected group. A 5s notification confirms deletion. The `default` group is not listed in vim.ui to avoid accidental removal.
- Marker lists: preview-only; no jumping. Previews show code context around the marker.
- ESC: closes/aborts the picker (uses each backend's native behavior).

### Commands

- `:MarkerGroupsPickerStatus` — shows available backends and current selection.
- `:MarkerGroupsSelect` — opens the picker when called without arguments.

### Configuration

Configure the picker in `setup()`:

```lua
require('marker-groups').setup({
  -- Accepted values: 'vim' | 'snacks' | 'fzf-lua' | 'mini.pick' | 'telescope'
  -- Invalid values fall back to 'vim'.
  picker = 'vim',
})
```

### Notes

- Use `:MarkerGroupsPickerStatus` to see available backends and current selection.
- mini.pick requires `require('mini.pick').setup()` in your config (if using your own mini.nvim); this plugin vendors mini.nvim for tests but does not force-enable it for you.
- Telescope requires `nvim-telescope/telescope.nvim` installed and configured.


