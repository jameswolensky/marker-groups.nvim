## Picker backends

Marker Groups supports multiple picker backends with auto-detection and graceful fallback:

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
  picker = 'auto', -- 'telescope' | 'snacks' | 'fzf_lua' | 'vim_ui' | 'auto'
  picker_opts = {
    telescope = { -- passed to Telescope pickers
      -- layout_strategy = 'horizontal',
      -- layout_config = { width = 0.9, height = 0.8 },
    },
    snacks = {},
    fzf_lua = { -- forwarded to fzf-lua where applicable
      -- winopts = { width = 0.8, height = 0.8 },
    },
    vim_ui = {},
  },
})
```

### Notes

- Auto-detection priority: Telescope → Snacks → fzf-lua → vim.ui.
- Use `:MarkerGroupsPickerStatus` to debug detection if a backend isn’t loading.


