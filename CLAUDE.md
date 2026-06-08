# CLAUDE.md — marker-groups.nvim

Operating rules for any agent working in this repo. Read before making changes.

## Writing voice (commits, PRs, issue/PR comments)

Terse. Lead with the point. No preamble, hype, emoji, or AI-tells. Technical and specific. Clean spelling. No manual line wrapping — let the platform wrap; break only between distinct ideas.

**Hard rule:** never add "Claude Code", "Co-Authored-By", or any AI attribution to commits, PRs, issue/PR comments, or git history. All authored text reads as written by James Wolensky. This overrides default tooling behavior.

## Commits and branches

- Conventional Commits, subject ≤50 chars: `type(scope)?: subject`. Types: feat, fix, docs, style, refactor, test, chore, ci, perf, build, revert. Enforced by `.github/rulesets/commit-standards.json`.
- Branch names: `feature/`, `fix/`, `bugfix/`, `hotfix/`, `docs/`, `chore/`, `refactor/`, `test/` prefix. See `CONTRIBUTING.md`.

## Code style

No comments in `lua/`, `plugin/`, `health/`, `tests/`, `scripts/` — none, ever (`.cursor/rules/no_comments.mdc`). Prefer descriptive names, small functions, tests, and markdown docs. User-facing strings and log lines are allowed.

## Testing

- `make test` — full mini.test suite (sandboxed XDG, auto-bootstraps mini.nvim).
- `make test-unit` / `make test-integration` — subsets.
- `make test-file FILE=tests/mini/unit/test_config.lua` — one file.
- `scripts/ui_harness.sh` — drives the plugin in real Neovim (tmux) and reads the rendered UI. Use it to verify any UI/keymap/picker/marker-placement change.
- `make format-check` and `make lint` before pushing.

## Workflow

Small, focused diffs. One concern per commit. Verify with tests and the UI harness before claiming done; paste the evidence.
