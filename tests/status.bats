load test_helper

setup() { setup_env; }
teardown() { teardown_env; }

@test "no sessions renders dim zero" {
  run "$BIN" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"○ 0/0"* ]]
}

@test "ready but seen renders count without new" {
  make_session 11 "a" user idle 500 "$HOME/apps/a" "a:@1.%1"
  make_session 12 "b" user busy 500 "$HOME/apps/b" "a:@1.%2"
  "$BIN" ack 11
  run "$BIN" status
  [[ "$output" == *"● 1/2"* ]]
  [[ "$output" != *"new"* ]]
}

@test "unseen renders highlighted new count" {
  make_session 11 "a" user idle 500 "$HOME/apps/a" "a:@1.%1"
  make_session 12 "b" user idle 500 "$HOME/apps/b" "a:@1.%2"
  make_session 13 "c" user busy 500 "$HOME/apps/c" "a:@1.%3"
  "$BIN" ack 12
  run "$BIN" status
  [[ "$output" == *"● 1 new"* ]]
  [[ "$output" == *"2/3"* ]]
  [[ "$output" == *"bg=#e0af68"* ]]
}

@test "desktop sessions excluded from counts" {
  make_session 11 "a" user idle 500 "$HOME/apps/a"
  run "$BIN" status
  [[ "$output" == *"○ 0/0"* ]]
}

@test "visible pane is auto-acked and not notified" {
  not_first_run
  make_session 11 "a" user idle 500 "$HOME/apps/a" "a:@1.%1"
  export STUB_CLIENT_PANES="%1\n"
  run "$BIN" status
  [[ "$output" == *"● 1/1"* ]]
  [ "$(jq -r '.seen["11"]' "$CLAUDE_SESSIONS_STATE")" = "500" ]
  [ "$(stub_log_lines osascript)" = "0" ]
}

@test "new unseen session notifies once with title and repo" {
  not_first_run
  make_session 11 "a-1" derived idle 500 "$HOME/apps/smart-proxy" "a:@1.%1"
  export STUB_PANE_TITLES="%1 _ PR 418 regressions\n"
  "$BIN" status >/dev/null
  "$BIN" status >/dev/null
  [ "$(stub_log_lines osascript)" = "1" ]
  grep -q 'display notification "PR 418 regressions" with title "smart-proxy ready"' "$STUB_LOG"
}

@test "notifies again after a busy to idle cycle" {
  not_first_run
  make_session 11 "a" user idle 500 "$HOME/apps/a" "a:@1.%1"
  "$BIN" status >/dev/null
  make_session 11 "a" user busy 600 "$HOME/apps/a" "a:@1.%1"
  "$BIN" status >/dev/null
  make_session 11 "a" user idle 700 "$HOME/apps/a" "a:@1.%1"
  "$BIN" status >/dev/null
  [ "$(stub_log_lines osascript)" = "2" ]
}

@test "desktop session never notifies" {
  not_first_run
  make_session 11 "a" user idle 500 "$HOME/apps/a"
  "$BIN" status >/dev/null
  [ "$(stub_log_lines osascript)" = "0" ]
}

@test "bell written to each client tty" {
  not_first_run
  make_session 11 "a" user idle 500 "$HOME/apps/a" "a:@1.%1"
  export STUB_CLIENT_TTYS="$TEST_TMP/tty1\n$TEST_TMP/tty2\n"
  "$BIN" status >/dev/null
  [ "$(od -An -c "$TEST_TMP/tty1" | tr -d ' ')" = "\\a" ]
  [ "$(od -An -c "$TEST_TMP/tty2" | tr -d ' ')" = "\\a" ]
}

@test "title with quotes and backslashes is escaped for osascript" {
  not_first_run
  make_session 11 'say "hi" \ bye' user idle 500 "$HOME/apps/a" "a:@1.%1"
  "$BIN" status >/dev/null
  grep -qF 'display notification "say \"hi\" \\ bye"' "$STUB_LOG"
}

@test "notified file pruned of dead pids" {
  make_session 11 "a" user idle 500 "$HOME/apps/a" "a:@1.%1"
  mkdir -p "$(dirname "$CLAUDE_SESSIONS_STATE")"
  echo '{"77":1}' > "$(dirname "$CLAUDE_SESSIONS_STATE")/notified.json"
  "$BIN" status >/dev/null
  [ "$(jq -c 'keys' "$(dirname "$CLAUDE_SESSIONS_STATE")/notified.json")" = '["11"]' ]
}

@test "osascript failure does not break status line" {
  not_first_run
  make_session 11 "a" user idle 500 "$HOME/apps/a" "a:@1.%1"
  mkdir -p "$TEST_TMP/badstubs"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$TEST_TMP/badstubs/osascript"
  chmod +x "$TEST_TMP/badstubs/osascript"
  run env PATH="$TEST_TMP/badstubs:$PATH" "$BIN" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"1 new"* ]]
}

@test "first run seeds notified file without notifying" {
  make_session 11 "a" user idle 500 "$HOME/apps/a" "a:@1.%1"
  make_session 12 "b" user idle 500 "$HOME/apps/b" "a:@1.%2"
  run "$BIN" status
  [[ "$output" == *"2 new"* ]]
  [ "$(stub_log_lines osascript)" = "0" ]
  [ "$(jq -c 'keys' "$(dirname "$CLAUDE_SESSIONS_STATE")/notified.json")" = '["11","12"]' ]
  make_session 13 "c" user idle 600 "$HOME/apps/c" "a:@1.%3"
  "$BIN" status >/dev/null
  [ "$(stub_log_lines osascript)" = "1" ]
}

@test "corrupt registry on status tick prints error marker, logs, exits 0" {
  not_first_run
  make_session 11 "a" user idle 500 "$HOME/apps/a" "a:@1.%1"
  : > "$CLAUDE_SESSIONS_DIR/11.json"
  run "$BIN" status
  [ "$status" -eq 0 ]
  [[ "$output" == *" ! "* ]]
  grep -q "11.json" "$(dirname "$CLAUDE_SESSIONS_STATE")/errors.log"
}
