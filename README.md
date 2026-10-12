# claude-sessions

One place for every Claude Code session running in tmux: which are busy, which
are waiting for you, and which of those you have not looked at yet.

Reads Claude Code's own registry (`~/.claude/sessions/*.json`). No hooks, no
daemon.

## Install

    ./install.sh

Then add the printed snippet to `~/.tmux.conf`. Requires bash >= 4.4 on PATH
(homebrew bash), jq, fzf, tmux.

## Use

- Status bar: `○ 0/4` nothing waiting · `● 2/4` two waiting, all seen ·
  `● 1 new · 2/4` one you have not looked at (highlighted).
- `prefix g`: popup list. Enter jumps to the pane. `ctrl-x` kills the session's
  tmux pane after a y/N prompt. `ctrl-t` sets your own title for a session. Preview on the right shows cwd, branch and recent prompts.
- If a tick fails (corrupt registry file, missing binary) the segment shows a red
  `!` and the reason is appended to `~/.cache/claude-sessions/errors.log`.
- Looking at a pane acknowledges it. A session becoming ready sends a macOS
  notification and a terminal bell. The very first tick after install seeds
  state silently so already-idle sessions do not all fire at once.

## Titles

Row title precedence: your `ctrl-t` override, then `/rename` in Claude Code,
then Claude's auto title.

## Dev

    brew install bats-core
    bats tests/

Env overrides for testing: `CLAUDE_SESSIONS_DIR`, `CLAUDE_SESSIONS_STATE`,
`CLAUDE_SESSIONS_PROJECTS_DIR`, `CLAUDE_SESSIONS_ALIVE_CMD`,
`CLAUDE_SESSIONS_NOW_MS`.
