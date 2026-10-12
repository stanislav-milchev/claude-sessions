load test_helper

setup() { setup_env; }
teardown() { teardown_env; }

@test "unknown subcommand exits 1 with usage" {
  run "$BIN" bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage"* ]]
}

@test "no subcommand exits 1 with usage" {
  run "$BIN"
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage"* ]]
}
