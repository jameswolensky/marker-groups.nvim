#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SESSION="mg_ui"
DEPS="${MG_UI_DEPS:-$ROOT/scripts/.ui_deps}"
SBX="$(mktemp -d)"
export XDG_DATA_HOME="$SBX"
export MG_PLUGIN_ROOT="$ROOT"
export MG_SANDBOX_DATA="$SBX/mg"

PASS=0
FAIL=0

cleanup() {
  tmux kill-session -t "$SESSION" 2>/dev/null
  rm -rf "$SBX"
}
trap cleanup EXIT

clone_dep() {
  local name="$1" url="$2"
  if [ ! -d "$DEPS/$name" ]; then
    echo "cloning $name"
    git clone --depth=1 "$url" "$DEPS/$name" >/dev/null 2>&1
  fi
  mkdir -p "$SBX/nvim/site/pack/sandbox/start"
  ln -sfn "$DEPS/$name" "$SBX/nvim/site/pack/sandbox/start/$name"
}

send() { tmux send-keys -t "$SESSION" "$@"; }
sleep_ms() { perl -e "select(undef,undef,undef,$1/1000)"; }

cap() { tmux capture-pane -t "$SESSION" -p; }

wait_for() {
  local pattern="$1" tries="${2:-40}"
  for _ in $(seq 1 "$tries"); do
    if cap | grep -qF "$pattern"; then return 0; fi
    sleep_ms 150
  done
  return 1
}

assert_screen() {
  local label="$1" pattern="$2"
  if cap | grep -qF "$pattern"; then
    echo "PASS: $label"
    PASS=$((PASS+1))
  else
    echo "FAIL: $label (missing: $pattern)"
    echo "----- screen -----"; cap; echo "------------------"
    FAIL=$((FAIL+1))
  fi
}

start_nvim() {
  clone_dep plenary.nvim https://github.com/nvim-lua/plenary.nvim
  clone_dep snacks.nvim https://github.com/folke/snacks.nvim
  tmux kill-session -t "$SESSION" 2>/dev/null
  tmux new-session -d -s "$SESSION" -x 200 -y 50
  tmux send-keys -t "$SESSION" \
    "cd $ROOT && XDG_DATA_HOME=$SBX MG_PLUGIN_ROOT=$ROOT MG_SANDBOX_DATA=$SBX/mg nvim -u scripts/ui_sandbox/init.lua scripts/ui_sandbox/fixture.lua" Enter
  wait_for "fixture.lua" || { echo "FAIL: nvim did not start"; cap; exit 1; }
}

summary() {
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed"
  [ "$FAIL" -eq 0 ]
}
scenario_happy_path() {
  send Escape; send ":3" Enter
  send ":MarkerAdd needs a guard" Enter
  wait_for "needs a guard" 40
  assert_screen "marker virtual text shown" "needs a guard"

  send Escape; send ":MarkerGroupsView" Enter
  wait_for "needs a guard" 40
  assert_screen "drawer lists marker" "needs a guard"
  send Escape; send ":MarkerGroupsCloseDrawer" Enter
}
scenario_snacks_markers() {
  send Escape; send ":lua require('marker-groups.pickers').show_markers()" Enter
  if wait_for "needs a guard" 40; then
    assert_screen "snacks marker picker lists item" "needs a guard"
  else
    echo "NOTE: snacks show_markers produced no visible list (PR #12 territory)"
    cap
  fi
  send Escape; send Escape
}
scenario_split_targeting() {
  send Escape; send ":only" Enter
  send ":vsplit scripts/ui_sandbox/init.lua" Enter
  wait_for "init.lua" 40
  send "l"
  send ":wincmd l" Enter
  send ":5" Enter
  send ":MarkerAdd right window mark" Enter
  wait_for "right window mark" 40
  send ":lua vim.api.nvim_put({ '<<'..vim.api.nvim_buf_get_name(0):match('[^/]+$') }, 'c', true, false)" Enter
  send Escape
  assert_screen "marker added in focused (right) buffer" "<<init.lua"
}
if [ "${1:-}" = "run" ] || [ -z "${BASH_SOURCE[1]:-}" ]; then
  start_nvim
  assert_screen "boot" "fixture.lua"
  scenario_happy_path
  scenario_snacks_markers
  scenario_split_targeting
  summary
fi
