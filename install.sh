#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target="$HOME/.local/bin/claude-sessions"

for bin in jq fzf tmux osascript; do
  command -v "$bin" >/dev/null 2>&1 || { printf 'missing: %s\n' "$bin" >&2; exit 1; }
done
bash -c 'shopt -s inherit_errexit' 2>/dev/null || { printf 'bash >= 4.4 required on PATH (brew install bash)\n' >&2; exit 1; }

mkdir -p "$HOME/.local/bin"
for name in claude-sessions tmux-claude-resume; do
  ln -sf "$here/bin/$name" "$HOME/.local/bin/$name"
  printf 'linked %s -> %s\n' "$HOME/.local/bin/$name" "$here/bin/$name"
done
printf '\n'

cat <<SNIPPET
Add to ~/.tmux.conf, then reload it (tmux source-file ~/.tmux.conf):

  set -g status-interval 3
  bind-key -r g display-popup -E -w 90% -h 60% "$target list"

and prepend the segment to your existing status-right, e.g.

  set -g status-right "#($target status) <your current status-right>"

Optional, to resume every Claude pane after a reboot (needs tpm, tmux-resurrect, tmux-continuum):

  set -g @continuum-restore 'on'
  set -g @resurrect-hook-post-save-all '$HOME/.local/bin/tmux-claude-resume save'
  set -g @resurrect-hook-post-restore-all '$HOME/.local/bin/tmux-claude-resume restore'

Optional, in your shell profile:

  export CLAUDE_SESSIONS_BASE_DIRS="\$HOME/apps:\$HOME/personal"   # repo label roots
  export CLAUDE_SESSIONS_STYLE_NEW='#[fg=#16161e,bg=#e0af68,bold]'  # also _READY _QUIET _ERROR
SNIPPET
