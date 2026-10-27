load test_helper

STARTED="Tue Oct 27 08:11:59 2026"

setup() {
  setup_env
  export TMUX="/tmp/tmux-test,1,0"
  export XDG_DATA_HOME="$TEST_TMP/data"
  export STUB_PROC_START="$STARTED"
  export CLAUDE_SESSIONS_CONFIG_DIRS="$HOME/.claude:$HOME/.claude-profiles/work"
  STATE="$XDG_DATA_HOME/tmux/resurrect/claude-sessions.tsv"
  RESUME="$BATS_TEST_DIRNAME/../bin/tmux-claude-resume"
}
teardown() { teardown_env; }

make_registry() {
  local config_dir="$1" pid="$2" sid="$3" cwd="$4" started="${5:-$STARTED}"
  mkdir -p "$config_dir/sessions"
  jq -n --argjson pid "$pid" --arg sid "$sid" --arg cwd "$cwd" --arg started "$started" \
    '{pid: $pid, sessionId: $sid, cwd: $cwd, procStart: $started}' > "$config_dir/sessions/$pid.json"
}

write_state() {
  mkdir -p "$(dirname "$STATE")"
  printf '%b' "$1" > "$STATE"
}

@test "save records each pane's own session when panes share a cwd" {
  export STUB_PANE_TITLES='vm:2.0\t100\nvm:3.0\t110\n'
  export STUB_CHILDREN="100:101 110:111"
  make_registry "$HOME/.claude-profiles/work" 101 sid-a "$HOME/apps/vm"
  make_registry "$HOME/.claude-profiles/work" 111 sid-b "$HOME/apps/vm"
  run "$RESUME" save
  [ "$status" -eq 0 ]
  [ "$(cat "$STATE")" = "$(printf 'vm:2.0\t%s\tsid-a\t%s\nvm:3.0\t%s\tsid-b\t%s' \
    "$HOME/.claude-profiles/work" "$HOME/apps/vm" "$HOME/.claude-profiles/work" "$HOME/apps/vm")" ]
}

@test "save finds claude nested below the pane shell" {
  export STUB_PANE_TITLES='s:1.0\t100\n'
  export STUB_CHILDREN="100:200 200:300"
  make_registry "$HOME/.claude" 300 sid-deep "$HOME/apps/a"
  run "$RESUME" save
  [ "$status" -eq 0 ]
  [ "$(cut -f1,3 "$STATE")" = "$(printf 's:1.0\tsid-deep')" ]
}

@test "save ignores a registry file left by an earlier process with the same pid" {
  export STUB_PANE_TITLES='s:1.0\t100\n'
  export STUB_CHILDREN="100:101"
  make_registry "$HOME/.claude" 101 sid-stale "$HOME/apps/a" "Mon Oct 26 01:00:00 2026"
  run "$RESUME" save
  [ "$status" -eq 0 ]
  [ ! -s "$STATE" ]
}

@test "save replaces the previous list when no pane runs claude" {
  write_state 'old:1.0\tdir\tsid-old\t/tmp\n'
  export STUB_PANE_TITLES='s:1.0\t100\n'
  run "$RESUME" save
  [ "$status" -eq 0 ]
  [ ! -s "$STATE" ]
}

@test "restore resumes each session in its pane, with the profile's config dir" {
  write_state "s:1.0\t$HOME/.claude\tsid-a\t$HOME/apps/a\ns:2.0\t$HOME/.claude-profiles/work\tsid-b\t$HOME/apps/b c\n"
  export STUB_PANE_COMMANDS='s:1.0\tzsh\ns:2.0\tzsh\n'
  run "$RESUME" restore
  [ "$status" -eq 0 ]
  grep -qF "tmux send-keys -t s:1.0 cd $HOME/apps/a && claude --resume sid-a Enter" "$STUB_LOG"
  grep -qF "tmux send-keys -t s:2.0 cd $HOME/apps/b\\ c && CLAUDE_CONFIG_DIR=$HOME/.claude-profiles/work claude --resume sid-b Enter" "$STUB_LOG"
}

@test "restore leaves busy and missing panes alone" {
  write_state "s:1.0\t$HOME/.claude\tsid-a\t$HOME/apps/a\ngone:1.0\t$HOME/.claude\tsid-b\t$HOME/apps/b\n"
  export STUB_PANE_COMMANDS='s:1.0\t2.1.311\n'
  run "$RESUME" restore
  [ "$status" -eq 0 ]
  [[ "$output" == *"skip s:1.0: pane busy with 2.1.311"* ]]
  [[ "$output" == *"skip gone:1.0: pane missing"* ]]
  [ "$(stub_log_lines send-keys)" = "0" ]
}

@test "restore --dry-run prints commands without sending them" {
  write_state "s:1.0\t$HOME/.claude\tsid-a\t$HOME/apps/a\n"
  export STUB_PANE_COMMANDS='s:1.0\t-zsh\n'
  run "$RESUME" restore --dry-run
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 's:1.0\tcd %s && claude --resume sid-a' "$HOME/apps/a")" ]
  [ "$(stub_log_lines send-keys)" = "0" ]
}

@test "restore fails when nothing was saved" {
  run "$RESUME" restore
  [ "$status" -eq 1 ]
  [[ "$output" == *"no saved claude sessions"* ]]
}

@test "refuses to run outside tmux" {
  unset TMUX
  run "$RESUME" save
  [ "$status" -eq 1 ]
  [[ "$output" == *"must run inside tmux"* ]]
}
