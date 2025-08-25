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
- `:MarkerGroupsPicker` — Open configured picker (auto/telescope/snacks/mini)
- `:MarkerGroupsPickerMarkers` — Open configured picker for active group markers
- removed Telescope-specific keymaps; use generic picker commands
- `:MarkerGroupsHealth` — Run health checks

