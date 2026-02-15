#!/usr/bin/env bats

# Tests for gg wt (worktrunk delegation)

setup() {
  load 'test_helper'

  TEST_DIR=$(mktemp -d)
  cd "$TEST_DIR"

  # Create a fake wt binary that echoes its arguments
  mkdir -p "$TEST_DIR/bin"
  cat > "$TEST_DIR/bin/wt" <<'SCRIPT'
#!/usr/bin/env bash
if [ $# -eq 0 ]; then
  echo "wt called"
else
  echo "wt called with: $*"
fi
SCRIPT
  chmod +x "$TEST_DIR/bin/wt"
  export PATH="$TEST_DIR/bin:$PATH"

  load_gg
}

teardown() {
  cd /
  rm -rf "$TEST_DIR"
}

# =============================================================================
# CORE FUNCTIONALITY
# =============================================================================

@test "wt: delegates to wt binary with no arguments" {
  run gg wt
  [ "$status" -eq 0 ]
  [[ "$output" == "wt called" ]]
}

@test "wt: passes single argument through" {
  run gg wt status
  [ "$status" -eq 0 ]
  [[ "$output" == "wt called with: status" ]]
}

@test "wt: passes multiple arguments through" {
  run gg wt log --oneline -n 5
  [ "$status" -eq 0 ]
  [[ "$output" == "wt called with: log --oneline -n 5" ]]
}

@test "wt: preserves exit code from wt" {
  cat > "$TEST_DIR/bin/wt" <<'SCRIPT'
#!/usr/bin/env bash
exit 42
SCRIPT
  chmod +x "$TEST_DIR/bin/wt"

  run gg wt
  [ "$status" -eq 42 ]
}

# =============================================================================
# METADATA
# =============================================================================

@test "wt: appears in help output" {
  run bash -c 'source "'"${BATS_TEST_DIRNAME}"'/../dot_config/dd-git-tools.zsh" 2>/dev/null && gg help'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "wt" ]]
  [[ "$output" =~ "worktrunk" ]]
}

@test "wt: listed in GG_CUSTOM_COMMANDS" {
  run bash -c 'source "'"${BATS_TEST_DIRNAME}"'/../dot_config/dd-git-tools.zsh" 2>/dev/null; printf "%s\n" "${GG_CUSTOM_COMMANDS[@]}"'
  [[ "$output" =~ "wt:delegate to worktrunk" ]]
}
