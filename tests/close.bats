load test_helper

setup() { setup_env; }
teardown() { teardown_env; }

@test "close kills the pane after y" {
  make_session 11 "PR 418" user idle 500 "$HOME/apps/a" "smart-proxy:@23.%23"
  run bash -c "echo y | '$BIN' close 11"
  [ "$status" -eq 0 ]
  [[ "$output" == *'kill "PR 418"? [y/N]'* ]]
  grep -q '^tmux kill-pane -t %23$' "$STUB_LOG"
}

@test "close does nothing on n or empty answer" {
  make_session 11 "PR 418" user idle 500 "$HOME/apps/a" "smart-proxy:@23.%23"
  run bash -c "echo n | '$BIN' close 11"
  [ "$status" -eq 0 ]
  run bash -c "echo | '$BIN' close 11"
  [ "$status" -eq 0 ]
  [ "$(stub_log_lines kill-pane)" = "0" ]
}

@test "close refuses desktop session" {
  make_session 11 "Desk" user idle 500 "$HOME/apps/a"
  run bash -c "echo y | '$BIN' close 11"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no tmux pane"* ]]
  [ "$(stub_log_lines kill-pane)" = "0" ]
}
