---
title: Commands
---

## Group Management

- `:MarkerGroupsCreate <name>` — Create a new group
- `:MarkerGroupsList` — List all groups
- `:MarkerGroupsSelect [name]` — Switch to a group
- `:MarkerGroupsRename <old> <new>` — Rename a group (new name up to 100 characters)
- `:MarkerGroupsDelete <name>` — Delete a group

## Marker Operations

- `:MarkerAdd [annotation]` — Add marker at cursor/selection (annotation up to 500 characters)
- `:MarkerRemove` — Remove marker at cursor
- `:MarkerList` — List markers in current buffer

## Viewing & Navigation

- `:MarkerGroupsView` — Open drawer marker viewer
- `:MarkerGroupsTelescope` — Telescope integration
- `:MarkerGroupsHealth` — Run health checks

## Picker Commands

- `:MarkerGroupsPickerStatus` — Show current picker backend and availability.
- `:MarkerGroupsSelect` (no argument) — Open the configured picker.

Behavior
- Group list: Enter deletes the selected group (5s notification confirms). ESC closes.
- Marker list: Preview-only; shows code context around the marker; no jumping.
- Backends: Telescope, Snacks.nvim, fzf-lua, vim.ui (auto-detected with fallback).

