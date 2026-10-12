load test_helper

setup() { setup_env; }
teardown() { teardown_env; }

@test "jump switches client, window, pane and acks" {
  make_session 11 "a" user idle 500 "$HOME/apps/a" "smart-proxy:@23.%23"
  run "$BIN" jump 11
  [ "$status" -eq 0 ]
  grep -q '^tmux switch-client -t smart-proxy$' "$STUB_LOG"
  grep -q '^tmux select-window -t smart-proxy:@23$' "$STUB_LOG"
  grep -q '^tmux select-pane -t %23$' "$STUB_LOG"
  [ "$(jq -r '.seen["11"]' "$CLAUDE_SESSIONS_STATE")" = "500" ]
}

@test "jump to desktop session fails" {
  make_session 11 "a" user idle 500 "$HOME/apps/a"
  run "$BIN" jump 11
  [ "$status" -eq 1 ]
  [[ "$output" == *"no tmux pane"* ]]
}

@test "jump to unknown pid fails" {
  run "$BIN" jump 99
  [ "$status" -eq 1 ]
}
