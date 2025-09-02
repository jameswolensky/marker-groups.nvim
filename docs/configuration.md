---
title: Configuration
---

```lua
require("marker-groups").setup({
  data_dir = vim.fn.stdpath("data") .. "/marker-groups",
  debug = false,
  log_level = "info",
  drawer_config = {
    width = 60,
    side = "right",
    border = "rounded",
    title_pos = "center",
  },
  context_lines = 2,
  max_annotation_display = 50,
  highlight_groups = {
    marker = "MarkerGroupsMarker",
    annotation = "MarkerGroupsAnnotation",
    context = "MarkerGroupsContext",
    multiline_start = "MarkerGroupsMultilineStart",
    multiline_end = "MarkerGroupsMultilineEnd",
  },
  keymaps = {
    enabled = true,
    prefix = "<leader>m",
    mappings = {
      marker = {
        add = { suffix = "a", mode = { "n", "v" }, desc = "Add marker" },
        edit = { suffix = "e", desc = "Edit marker at cursor" },
        delete = { suffix = "d", desc = "Delete marker at cursor" },
        list = { suffix = "l", desc = "List markers in buffer" },
          },
      group = {
        create = { suffix = "gc", desc = "Create marker group" },
        select = { suffix = "gs", desc = "Select marker group" },
        list = { suffix = "gl", desc = "List marker groups" },
        rename = { suffix = "gr", desc = "Rename marker group" },
        delete = { suffix = "gd", desc = "Delete marker group" },
      },
      view = { toggle = { suffix = "v", desc = "Toggle drawer marker viewer" } },
      telescope = {
        groups = { suffix = "tg", desc = "Telescope: marker groups" },
        markers = { suffix = "tm", desc = "Telescope: markers in active group" },
      },
    },
  },
  -- Picker backend (default: 'vim')
  -- Strict options: 'vim' | 'telescope' | 'snacks' | 'fzf-lua'
  -- Invalid values fall back to 'vim'.
  picker = 'vim',
})
```

## Limits

- Annotations: up to 500 UTF‑8 characters (inputs longer than this are truncated)
- Group names: up to 100 UTF‑8 characters (inputs longer than this are truncated)


