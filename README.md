# marker-groups.nvim

A powerful Neovim plugin for organizing and annotating code with grouped markers. Perfect for code reviews, debugging sessions, and project navigation.

## ✨ Features

- **📝 Smart Markers**: Add single-line or multi-line markers with annotations
- **🗂️ Group Organization**: Organize markers into logical groups (features, bugs, todos, etc.)
- **🎯 Visual Indicators**: See markers directly in your code with virtual text
- **🪟 Floating Viewer**: Beautiful floating window to browse all markers
- **🔍 Telescope Integration**: Fuzzy search through markers and groups
- **💾 Persistent Storage**: Markers survive Neovim restarts with automatic saving
- **⌨️ Rich Keybindings**: Intuitive keymaps for all operations
- **🔧 Configurable**: Extensive customization options

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "yourusername/marker-groups.nvim",
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

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "yourusername/marker-groups.nvim",
  requires = {
    "nvim-lua/plenary.nvim", -- Required
    "nvim-telescope/telescope.nvim", -- Optional
  },
  config = function()
    require("marker-groups").setup()
  end,
}
```

## 🚀 Quick Start

```lua
-- Basic setup with defaults
require("marker-groups").setup()

-- Create a new group
:MarkerGroupsCreate feature-auth

-- Add a marker at current line
:MarkerAdd Implement JWT token validation

-- View all markers in floating window
:MarkerGroupsView

-- List all groups
:MarkerGroupsList
```

## ⌨️ Default Keybindings

| Keymap | Action | Description |
|--------|--------|-------------|
| `<leader>ma` | Add marker | Add marker at cursor or visual selection |
| `<leader>mv` | View markers | Open floating marker viewer |
| `<leader>mgc` | Create group | Create a new marker group |
| `<leader>mgl` | List groups | List all marker groups |
| `<leader>mgs` | Select group | Switch to a different group |
| `<leader>mgr` | Rename group | Rename the current group |
| `<leader>mgd` | Delete group | Delete a marker group |
| `<leader>mt` | Telescope | Open Telescope marker search |

## 📖 Commands

### Group Management
- `:MarkerGroupsCreate <name>` - Create a new group
- `:MarkerGroupsList` - List all groups
- `:MarkerGroupsSelect [name]` - Switch to a group
- `:MarkerGroupsRename <old> <new>` - Rename a group
- `:MarkerGroupsDelete <name>` - Delete a group

### Marker Operations
- `:MarkerAdd [annotation]` - Add marker at cursor/selection
- `:MarkerRemove` - Remove marker at cursor
- `:MarkerList` - List markers in current group
- `:MarkerJump <id>` - Jump to specific marker

### Viewing & Navigation
- `:MarkerGroupsView` - Open floating marker viewer
- `:MarkerGroupsTelescope` - Open Telescope integration
- `:MarkerGroupsHealth` - Run health checks

## ⚙️ Configuration

```lua
require("marker-groups").setup({
  -- Data directory for persistent storage
  data_dir = vim.fn.stdpath("data") .. "/marker-groups",
  
  -- Enable debug logging
  debug = false,
  
  -- Log level: "debug", "info", "warn", "error"
  log_level = "info",
  
  -- Virtual text configuration
  virtual_text = {
    enabled = true,
    prefix = "📍 ",
    suffix = "",
    highlight = "Comment",
  },
  
  -- Floating window configuration
  floating = {
    border = "rounded",
    width = 0.8,
    height = 0.8,
    context_lines = 2,
  },
  
  -- Keybinding configuration
  keymaps = {
    enabled = true,
    prefix = "<leader>m",
  },
  
  -- Auto-save settings
  auto_save = {
    enabled = true,
    interval = 5000, -- milliseconds
  },
})
```

## 🎯 Use Cases

### Code Reviews
```lua
-- Create a group for review comments
:MarkerGroupsCreate code-review

-- Add markers for issues found
:MarkerAdd TODO: Extract this function
:MarkerAdd FIXME: Handle edge case for empty array
:MarkerAdd NOTE: Consider performance optimization
```

### Feature Development
```lua
-- Organize by feature branches
:MarkerGroupsCreate feature-user-auth
:MarkerAdd Implement login endpoint
:MarkerAdd Add password validation
:MarkerAdd Create user session management
```

### Bug Tracking
```lua
-- Track bugs and fixes
:MarkerGroupsCreate bug-fixes
:MarkerAdd BUG: Memory leak in data processing
:MarkerAdd FIX: Null pointer exception handling
```

## 🔍 Floating Window Navigation

The floating marker viewer provides rich navigation:

- **`j/k`** or **`↑/↓`** - Navigate between markers
- **`Enter`** - Jump to marker location
- **`q/Esc`** - Close window
- **`?`** - Show help

## 🧪 Health Checks

Run `:MarkerGroupsHealth` to verify:
- ✅ Neovim version compatibility
- ✅ Required dependencies
- ✅ Plugin initialization
- ✅ Data directory accessibility
- ✅ Configuration validity

## 🤝 Contributing

Contributions are welcome! Please see [DEVELOPMENT.md](DEVELOPMENT.md) for development setup and guidelines.

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- Telescope integration via [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- Inspired by various code annotation and marker plugins

---

**marker-groups.nvim** - Organize your code, annotate your thoughts, navigate with purpose. 🎯