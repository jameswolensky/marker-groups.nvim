## Picker backends

Marker Groups supports multiple picker backends (strict selection with fallback to vim):

- Telescope (rich previews; ESC closes)
- Snacks.nvim (previews; native close behavior)
- fzf-lua (previews; ESC aborts)
- vim.ui.select (basic, always available)

### Behavior

- Group lists: Enter deletes the selected group. A 5s notification confirms deletion. The `default` group is not listed in vim.ui to avoid accidental removal.
- Marker lists: preview-only; no jumping. Previews show code context around the marker.
- ESC: closes/aborts the picker (uses each backend's native behavior; Telescope explicitly mapped).

### Commands

- `:MarkerGroupsPickerStatus` — shows available backends and current selection.
- `:MarkerGroupsSelect` — opens the picker when called without arguments.

### Configuration

Configure the picker in `setup()`:

```lua
require('marker-groups').setup({
  -- Strict options: 'vim' | 'telescope' | 'snacks' | 'fzf-lua'
  -- Default is 'vim'. Invalid values fall back to 'vim'.
  picker = 'vim',
})
```

### Notes

- Use `:MarkerGroupsPickerStatus` to see available backends and current selection.


