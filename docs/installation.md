---
title: Installation
---

## Using lazy.nvim

```lua
{
  "jameswolensky/marker-groups.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim", -- Required
    "nvim-telescope/telescope.nvim", -- Optional: for fuzzy search
  },
  config = function()
    require("marker-groups").setup({
      -- Your configuration here
    })
  end,
}
```

### Picker detection and resolution

- Pickers are optional. If installed anywhere in Neovim, their existing configuration will be used.
- With `picker.provider = "auto"`, resolution order is: `telescope` → `snacks` → `mini` → `vim` (built-in `vim.ui`).
- To force the built-in UI, set `picker.provider = "vim"` in `setup()`.

## Using packer.nvim

```lua
use {
  "jameswolensky/marker-groups.nvim",
  requires = {
    "nvim-lua/plenary.nvim", -- Required
    "nvim-telescope/telescope.nvim", -- Optional
  },
  config = function()
    require("marker-groups").setup()
  end,
}
```


