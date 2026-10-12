load test_helper

setup() { setup_env; }
teardown() { teardown_env; }

@test "empty registry prints nothing" {
  run "$BIN" snapshot
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "dead pid is skipped" {
  make_session 11 "a-1" derived idle 1 "$HOME/apps/a" "a:@1.%1"
  export STUB_ALIVE_PIDS=""
  run "$BIN" snapshot
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "missing field fails with path" {
  make_session 11 "a-1" derived idle 1 "$HOME/apps/a" "a:@1.%1"
  jq 'del(.status)' "$CLAUDE_SESSIONS_DIR/11.json" > "$TEST_TMP/x" && mv "$TEST_TMP/x" "$CLAUDE_SESSIONS_DIR/11.json"
  run "$BIN" snapshot
  [ "$status" -ne 0 ]
  [[ "$output" == *"11.json"* ]]
  [[ "$output" == *"status"* ]]
}

@test "unparsable registry file fails with path" {
  make_session 11 "a-1" derived idle 1 "$HOME/apps/a" "a:@1.%1"
  : > "$CLAUDE_SESSIONS_DIR/11.json"
  run "$BIN" snapshot
  [ "$status" -ne 0 ]
  [[ "$output" == *"11.json"* ]]
}

@test "derived name uses pane title stripped of glyph" {
  make_session 11 "smart-proxy-51" derived idle 1 "$HOME/apps/smart-proxy" "smart-proxy:@23.%23"
  export STUB_PANE_TITLES="%23 _ MII-2017 and MII-2018\n%9 other\n"
  run "$BIN" snapshot
  [ "$(jq -r .title <<<"$output")" = "MII-2017 and MII-2018" ]
  [ "$(jq -r .pane <<<"$output")" = "%23" ]
}

@test "non-derived name wins over pane title" {
  make_session 11 "My renamed session" user idle 1 "$HOME/apps/a" "a:@1.%1"
  export STUB_PANE_TITLES="%1 _ junk\n"
  run "$BIN" snapshot
  [ "$(jq -r .title <<<"$output")" = "My renamed session" ]
}

@test "manual title override wins over everything" {
  make_session 11 "My renamed session" user idle 1 "$HOME/apps/a" "a:@1.%1"
  mkdir -p "$(dirname "$CLAUDE_SESSIONS_STATE")"
  echo '{"seen":{},"titles":{"11":"custom"}}' > "$CLAUDE_SESSIONS_STATE"
  run "$BIN" snapshot
  [ "$(jq -r .title <<<"$output")" = "custom" ]
}

@test "derived name with empty pane title falls back to name" {
  make_session 11 "a-1" derived idle 1 "$HOME/apps/a" "a:@1.%1"
  run "$BIN" snapshot
  [ "$(jq -r .title <<<"$output")" = "a-1" ]
}

@test "desktop session has empty tmux and is never unseen" {
  make_session 11 "Desktop thing" user idle 1 "$HOME/apps/a"
  run "$BIN" snapshot
  [ "$(jq -r .tmux <<<"$output")" = "" ]
  [ "$(jq -r .unseen <<<"$output")" = "false" ]
  [ "$(jq -r .ready <<<"$output")" = "true" ]
}

@test "repo label strips apps prefix and renders worktree" {
  make_session 11 "a" user idle 1 "$HOME/apps/browser-farm/.claude/worktrees/MII-1995+x" "a:@1.%1"
  make_session 12 "b" user idle 1 "$HOME/apps/crawl-agents/.worktrees/MII-2029" "a:@1.%2"
  make_session 13 "c" user idle 1 "$HOME/personal/tool" "a:@1.%3"
  run "$BIN" snapshot
  [ "$(jq -r 'select(.pid==11).repo' <<<"$output")" = "browser-farm ⎇ MII-1995+x" ]
  [ "$(jq -r 'select(.pid==12).repo' <<<"$output")" = "crawl-agents ⎇ MII-2029" ]
  [ "$(jq -r 'select(.pid==13).repo' <<<"$output")" = "tool" ]
}

@test "ready and unseen computed against seen state" {
  make_session 11 "a" user idle 500 "$HOME/apps/a" "a:@1.%1"
  make_session 12 "b" user idle 500 "$HOME/apps/b" "a:@1.%2"
  make_session 13 "c" user busy 500 "$HOME/apps/c" "a:@1.%3"
  mkdir -p "$(dirname "$CLAUDE_SESSIONS_STATE")"
  echo '{"seen":{"12":500},"titles":{}}' > "$CLAUDE_SESSIONS_STATE"
  run "$BIN" snapshot
  [ "$(jq -r 'select(.pid==11).unseen' <<<"$output")" = "true" ]
  [ "$(jq -r 'select(.pid==12).unseen' <<<"$output")" = "false" ]
  [ "$(jq -r 'select(.pid==12).ready' <<<"$output")" = "true" ]
  [ "$(jq -r 'select(.pid==13).ready' <<<"$output")" = "false" ]
  [ "$(jq -r 'select(.pid==13).unseen' <<<"$output")" = "false" ]
}

@test "idleFor is seconds since statusUpdatedAt" {
  make_session 11 "a" user idle 999999760000 "$HOME/apps/a" "a:@1.%1"
  run "$BIN" snapshot
  [ "$(jq -r .idleFor <<<"$output")" = "240" ]
}

@test "sort order: unseen oldest first, then ready-seen, busy, desktop" {
  make_session 11 "busy" user busy 100 "$HOME/apps/a" "a:@1.%1"
  make_session 12 "desktop" user idle 100 "$HOME/apps/a"
  make_session 13 "unseen-new" user idle 300 "$HOME/apps/a" "a:@1.%3"
  make_session 14 "unseen-old" user idle 200 "$HOME/apps/a" "a:@1.%4"
  make_session 15 "seen" user idle 100 "$HOME/apps/a" "a:@1.%5"
  mkdir -p "$(dirname "$CLAUDE_SESSIONS_STATE")"
  echo '{"seen":{"15":100},"titles":{}}' > "$CLAUDE_SESSIONS_STATE"
  run "$BIN" snapshot
  [ "$(jq -r .name <<<"$output" | tr '\n' ' ')" = "unseen-old unseen-new seen busy desktop " ]
}

@test "corrupt state file fails with path" {
  make_session 11 "a" user idle 1 "$HOME/apps/a" "a:@1.%1"
  mkdir -p "$(dirname "$CLAUDE_SESSIONS_STATE")"
  echo '{"seen":[]}' > "$CLAUDE_SESSIONS_STATE"
  run "$BIN" snapshot
  [ "$status" -ne 0 ]
  [[ "$output" == *"seen.json"* ]]
}

@test "missing nameSource is treated as non-derived" {
  make_session 11 "Desktop title" user idle 1 "$HOME/apps/a"
  jq 'del(.nameSource)' "$CLAUDE_SESSIONS_DIR/11.json" > "$TEST_TMP/x" && mv "$TEST_TMP/x" "$CLAUDE_SESSIONS_DIR/11.json"
  run "$BIN" snapshot
  [ "$status" -eq 0 ]
  [ "$(jq -r .title <<<"$output")" = "Desktop title" ]
}

@test "repo label outside apps and personal is the basename" {
  make_session 11 "a" user idle 1 "/Users/stan/Library/Application Support/Claude/scratch-2026-10-08"
  run "$BIN" snapshot
  [ "$(jq -r .repo <<<"$output")" = "scratch-2026-10-08" ]
}

@test "stale file whose procStart does not match the running process is skipped" {
  make_session 11 "a" user idle 1 "$HOME/apps/a" "a:@1.%1"
  jq '.procStart = "Mon Oct 12 07:28:14 2026"' "$CLAUDE_SESSIONS_DIR/11.json" > "$TEST_TMP/x" && mv "$TEST_TMP/x" "$CLAUDE_SESSIONS_DIR/11.json"
  export STUB_PROC_START="Tue Oct 13 09:00:00 2026"
  run "$BIN" snapshot
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "file whose procStart matches the running process is kept" {
  make_session 11 "a" user idle 1 "$HOME/apps/a" "a:@1.%1"
  jq '.procStart = "Mon Oct 12 07:28:14 2026"' "$CLAUDE_SESSIONS_DIR/11.json" > "$TEST_TMP/x" && mv "$TEST_TMP/x" "$CLAUDE_SESSIONS_DIR/11.json"
  export STUB_PROC_START="  Mon Oct 12 07:28:14 2026"
  run "$BIN" snapshot
  [ "$(jq -r .pid <<<"$output")" = "11" ]
}

@test "repo label honours CLAUDE_SESSIONS_BASE_DIRS" {
  export CLAUDE_SESSIONS_BASE_DIRS="$HOME/code:$HOME/work"
  make_session 11 "a" user idle 1 "$HOME/code/foo/sub/dir" "a:@1.%1"
  make_session 12 "b" user idle 1 "$HOME/work/bar/.worktrees/X/pkg" "a:@1.%2"
  make_session 13 "c" user idle 1 "$HOME/apps/baz/sub" "a:@1.%3"
  run "$BIN" snapshot
  [ "$(jq -r 'select(.pid==11).repo' <<<"$output")" = "foo/sub/dir" ]
  [ "$(jq -r 'select(.pid==12).repo' <<<"$output")" = "bar ⎇ X/pkg" ]
  [ "$(jq -r 'select(.pid==13).repo' <<<"$output")" = "sub" ]
}
