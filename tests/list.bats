load test_helper

setup() { setup_env; }
teardown() { teardown_env; }

@test "rows: pid first column, marker and columns in display" {
  make_session 11 "Unseen one" user idle 999999760000 "$HOME/apps/smart-proxy" "a:@1.%1"
  make_session 12 "Busy one" user busy 999999760000 "$HOME/apps/crawl-agents" "a:@1.%2"
  make_session 13 "Desk" user idle 999999760000 "$HOME/apps/x"
  run "$BIN" rows
  [ "$status" -eq 0 ]
  line1="$(sed -n 1p <<<"$output")"
  line2="$(sed -n 2p <<<"$output")"
  line3="$(sed -n 3p <<<"$output")"
  [ "$(cut -f1 <<<"$line1")" = "11" ]
  [[ "$(cut -f2 <<<"$line1")" == "● Unseen one"*"idle"*"4m"*"smart-proxy" ]]
  [[ "$(cut -f2 <<<"$line2")" == "  Busy one"*"busy"* ]]
  [[ "$(cut -f2 <<<"$line2")" != *"4m"* ]]
  [[ "$(cut -f2 <<<"$line3")" == "~ Desk"* ]]
}

@test "rows: seen ready uses dot marker" {
  make_session 11 "Seen" user idle 500 "$HOME/apps/a" "a:@1.%1"
  "$BIN" ack 11
  run "$BIN" rows
  [[ "$(cut -f2 <<<"$output")" == "· Seen"* ]]
}

@test "rows: age units" {
  make_session 11 "s" user idle 999999999000 "$HOME/apps/a" "a:@1.%1"
  make_session 12 "h" user idle 999992800000 "$HOME/apps/a" "a:@1.%2"
  make_session 13 "d" user idle 999827200000 "$HOME/apps/a" "a:@1.%3"
  run "$BIN" rows
  [[ "$output" == *" 1s "* ]]
  [[ "$output" == *" 2h "* ]]
  [[ "$output" == *" 2d "* ]]
}

@test "preview shows cwd, branch and filtered prompts" {
  make_session 11 "a" user idle 500 "$HOME/apps/a" "a:@1.%1"
  export STUB_GIT_BRANCH="MII-1995/invisible-playwright-worker"
  mkdir -p "$CLAUDE_SESSIONS_PROJECTS_DIR/-Users-x"
  {
    echo '{"type":"user","message":{"content":"<local-command-caveat>ignored system text here</local-command-caveat>"}}'
    echo '{"type":"user","message":{"content":"yes"}}'
    echo '{"type":"user","message":{"content":[{"type":"tool_result"}]}}'
    echo '{"type":"user","message":{"content":"review pr 418, make sure that it does not regress\nsecond line"}}'
    echo '{"type":"assistant","message":{"content":"irrelevant assistant text that is long"}}'
    echo '{"type":"user","message":{"content":"now post the review comments to github"}}'
  } > "$CLAUDE_SESSIONS_PROJECTS_DIR/-Users-x/sid-11.jsonl"
  run "$BIN" preview 11
  [ "$status" -eq 0 ]
  [[ "$output" == *"$HOME/apps/a"* ]]
  [[ "$output" == *"MII-1995/invisible-playwright-worker"* ]]
  [[ "$output" == *"review pr 418, make sure that it does not regress"* ]]
  [[ "$output" == *"now post the review comments to github"* ]]
  [[ "$output" != *"second line"* ]]
  [[ "$output" != *"ignored system text"* ]]
  [[ "$output" != *"irrelevant assistant"* ]]
}

@test "preview without transcript or git still exits 0" {
  make_session 11 "a" user idle 500 "$HOME/apps/a" "a:@1.%1"
  run "$BIN" preview 11
  [ "$status" -eq 0 ]
  [[ "$output" == *"no transcript"* ]]
  [[ "$output" == *"branch: -"* ]]
}

@test "preview shows at most five prompts, most recent last" {
  make_session 11 "a" user idle 500 "$HOME/apps/a" "a:@1.%1"
  mkdir -p "$CLAUDE_SESSIONS_PROJECTS_DIR/p"
  for i in 1 2 3 4 5 6 7; do
    echo "{\"type\":\"user\",\"message\":{\"content\":\"prompt number $i with enough length\"}}"
  done > "$CLAUDE_SESSIONS_PROJECTS_DIR/p/sid-11.jsonl"
  run "$BIN" preview 11
  [[ "$output" != *"prompt number 2 "* ]]
  [[ "$output" == *"prompt number 3 "* ]]
  [ "$(grep -c 'prompt number' <<<"$output")" = "5" ]
}

@test "preview drops meta, sidechain and compaction records" {
  make_session 11 "a" user idle 500 "$HOME/apps/a" "a:@1.%1"
  mkdir -p "$CLAUDE_SESSIONS_PROJECTS_DIR/p"
  {
    echo '{"type":"user","message":{"content":"a genuine prompt that is long enough to show"}}'
    echo '{"type":"user","isMeta":true,"message":{"content":"Another Claude session sent a message: hello there"}}'
    echo '{"type":"user","isSidechain":true,"message":{"content":"sidechain prompt that is long enough to show"}}'
    echo '{"type":"user","message":{"content":"This session is being continued from a previous conversation that ran out of context."}}'
  } > "$CLAUDE_SESSIONS_PROJECTS_DIR/p/sid-11.jsonl"
  run "$BIN" preview 11
  [[ "$output" == *"a genuine prompt"* ]]
  [[ "$output" != *"Another Claude session"* ]]
  [[ "$output" != *"sidechain prompt"* ]]
  [[ "$output" != *"being continued"* ]]
}

@test "rows truncates titles by characters, not bytes" {
  make_session 11 "Jev’s confidence docs for crawler ticket — long and longer" user idle 500 "$HOME/apps/a" "a:@1.%1"
  run "$BIN" rows
  [[ "$output" == *"Jev’s confidence docs for crawler ticket — l "* ]]
  [[ "$output" != *"— lo"* ]]
  [[ "$output" != *$'\xef\xbf\xbd'* ]]
}

@test "preview shows short prompts but drops trivial ones" {
  make_session 11 "a" user idle 500 "$HOME/apps/a" "a:@1.%1"
  mkdir -p "$CLAUDE_SESSIONS_PROJECTS_DIR/p"
  {
    echo '{"type":"user","message":{"content":"test"}}'
    echo '{"type":"user","message":{"content":"yes"}}'
    echo '{"type":"user","message":{"content":"whats this repo do"}}'
  } > "$CLAUDE_SESSIONS_PROJECTS_DIR/p/sid-11.jsonl"
  run "$BIN" preview 11
  [[ "$output" == *"• test"* ]]
  [[ "$output" == *"• whats this repo do"* ]]
  [[ "$output" != *"• yes"* ]]
}

@test "preview prints (none) when no prompt qualifies" {
  make_session 11 "a" user idle 500 "$HOME/apps/a" "a:@1.%1"
  mkdir -p "$CLAUDE_SESSIONS_PROJECTS_DIR/p"
  echo '{"type":"user","message":{"content":"ok"}}' > "$CLAUDE_SESSIONS_PROJECTS_DIR/p/sid-11.jsonl"
  run "$BIN" preview 11
  [[ "$output" == *"(none)"* ]]
}

@test "preview reads the transcript from the session's own profile" {
  export CLAUDE_SESSIONS_CONFIG_DIRS="$TEST_TMP/cfg:$TEST_TMP/profiles/test"
  make_profile_session "$TEST_TMP/profiles/test/sessions" 12 "b" user idle 500 "$HOME/apps/b" "a:@1.%2"
  mkdir -p "$TEST_TMP/profiles/test/projects/p"
  echo '{"type":"user","message":{"content":"prompt from the test profile"}}' > "$TEST_TMP/profiles/test/projects/p/sid-12.jsonl"
  run "$BIN" preview 12
  [[ "$output" == *"prompt from the test profile"* ]]
}
