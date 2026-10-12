load test_helper

setup() { setup_env; }
teardown() { teardown_env; }

@test "ack records statusUpdatedAt and creates state dir" {
  make_session 11 "a" user idle 500 "$HOME/apps/a" "a:@1.%1"
  run "$BIN" ack 11
  [ "$status" -eq 0 ]
  [ "$(jq -r '.seen["11"]' "$CLAUDE_SESSIONS_STATE")" = "500" ]
  run "$BIN" snapshot
  [ "$(jq -r .unseen <<<"$output")" = "false" ]
}

@test "ack unknown pid fails" {
  run "$BIN" ack 99
  [ "$status" -eq 1 ]
  [[ "$output" == *"99"* ]]
}

@test "title sets override and clears with empty text" {
  make_session 11 "a" user idle 500 "$HOME/apps/a" "a:@1.%1"
  run "$BIN" title 11 "my thing"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.titles["11"]' "$CLAUDE_SESSIONS_STATE")" = "my thing" ]
  run "$BIN" snapshot
  [ "$(jq -r .title <<<"$output")" = "my thing" ]
  run "$BIN" title 11 ""
  [ "$(jq -r '.titles["11"]' "$CLAUDE_SESSIONS_STATE")" = "null" ]
}

@test "title reads from stdin when no text given" {
  make_session 11 "a" user idle 500 "$HOME/apps/a" "a:@1.%1"
  run bash -c "echo typed | '$BIN' title 11"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.titles["11"]' "$CLAUDE_SESSIONS_STATE")" = "typed" ]
}

@test "writes prune dead pids from seen and titles" {
  make_session 11 "a" user idle 500 "$HOME/apps/a" "a:@1.%1"
  mkdir -p "$(dirname "$CLAUDE_SESSIONS_STATE")"
  echo '{"seen":{"77":1},"titles":{"77":"gone","11":"keep"}}' > "$CLAUDE_SESSIONS_STATE"
  run "$BIN" ack 11
  [ "$(jq -c '.seen|keys' "$CLAUDE_SESSIONS_STATE")" = '["11"]' ]
  [ "$(jq -c '.titles|keys' "$CLAUDE_SESSIONS_STATE")" = '["11"]' ]
}

@test "write is atomic: no temp file left behind" {
  make_session 11 "a" user idle 500 "$HOME/apps/a" "a:@1.%1"
  "$BIN" ack 11
  [ "$(ls "$(dirname "$CLAUDE_SESSIONS_STATE")" | wc -l | tr -d ' ')" = "1" ]
}
