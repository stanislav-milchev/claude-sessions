setup_env() {
  TEST_TMP="$(mktemp -d)"
  export HOME="$TEST_TMP/home"
  export CLAUDE_SESSIONS_DIR="$TEST_TMP/sessions"
  export CLAUDE_SESSIONS_STATE="$TEST_TMP/state/seen.json"
  export CLAUDE_SESSIONS_PROJECTS_DIR="$TEST_TMP/projects"
  export CLAUDE_SESSIONS_ALIVE_CMD="$BATS_TEST_DIRNAME/stubs/alive"
  export CLAUDE_SESSIONS_NOW_MS=1000000000000
  export STUB_LOG="$TEST_TMP/stub.log"
  export STUB_ALIVE_PIDS=""
  export STUB_PANE_TITLES=""
  export STUB_CLIENT_PANES=""
  export STUB_CLIENT_TTYS="/dev/null\n"
  export STUB_GIT_BRANCH=""
  export PATH="$BATS_TEST_DIRNAME/stubs:$PATH"
  mkdir -p "$HOME" "$CLAUDE_SESSIONS_DIR" "$CLAUDE_SESSIONS_PROJECTS_DIR"
  : > "$STUB_LOG"
  BIN="$BATS_TEST_DIRNAME/../bin/claude-sessions"
}

teardown_env() {
  rm -rf "$TEST_TMP"
}

make_session() {
  local pid="$1" name="$2" name_source="$3" status="$4" status_at="$5" cwd="$6" tmux="${7:-}"
  jq -n --argjson pid "$pid" --arg name "$name" --arg ns "$name_source" --arg st "$status" \
    --argjson at "$status_at" --arg cwd "$cwd" --arg tmux "$tmux" --arg sid "sid-$pid" \
    '{pid: $pid, sessionId: $sid, name: $name, nameSource: $ns, status: $st,
      statusUpdatedAt: $at, cwd: $cwd} + (if $tmux == "" then {} else {tmux: $tmux} end)' \
    > "$CLAUDE_SESSIONS_DIR/$pid.json"
  STUB_ALIVE_PIDS="$STUB_ALIVE_PIDS $pid"
  export STUB_ALIVE_PIDS
}

stub_log_lines() {
  grep -c "$1" "$STUB_LOG" || true
}
