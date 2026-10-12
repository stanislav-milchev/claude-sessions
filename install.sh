#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target="$HOME/.local/bin/claude-sessions"

mkdir -p "$HOME/.local/bin"
ln -sf "$here/bin/claude-sessions" "$target"
printf 'linked %s -> %s\n\n' "$target" "$here/bin/claude-sessions"

cat <<'SNIPPET'
Add to ~/.tmux.conf (then: prefix r to reload):

set -g status-interval 3
set -g status-right "#(claude-sessions status) #[fg=#7aa2f7,bg=#3b4261] %Y-%m-%d  %H:%M "
bind-key -r g display-popup -E -w 90% -h 60% "claude-sessions list"
SNIPPET
