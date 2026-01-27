#!/usr/bin/env bats

# Tests for gg tab completion
# These tests verify that completion works without infinite recursion

setup() {
  load 'test_helper'
  # Create temp directory for test repos
  TEST_DIR=$(mktemp -d)
  cd "$TEST_DIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "test" > test.txt
  git add . && git commit -qm "init"
}

teardown() {
  cd /
  rm -rf "$TEST_DIR"
}

# =============================================================================
# RECURSION PREVENTION
# =============================================================================

@test "completion: no infinite recursion when pressing tab" {
  # This test verifies PR #6 fix - _gg should not recurse infinitely
  # The issue was that _git would call back to _gg if service wasn't set to 'git'

  run zsh -c '
    autoload -Uz compinit
    compinit -u 2>/dev/null

    source "'"${BATS_TEST_DIRNAME}"'/../dot_config/dd-git-tools.zsh"

    # Track _gg calls to detect recursion
    typeset -gi _GG_CALL_COUNT=0

    # Wrap _gg to count calls
    eval "_gg_original=$(functions _gg)"
    _gg() {
      (( _GG_CALL_COUNT++ ))
      if (( _GG_CALL_COUNT > 5 )); then
        echo "RECURSION_DETECTED"
        return 1
      fi
      _gg_original "$@"
    }
    compdef _gg gg 2>/dev/null

    # Simulate completion context
    CURRENT=2
    words=(gg "")
    service=gg

    # Try completion (may fail with "can only be called from completion function"
    # but should not recurse)
    _gg 2>/dev/null

    echo "CALL_COUNT=$_GG_CALL_COUNT"
  '

  # Should not detect recursion
  [[ ! "$output" =~ "RECURSION_DETECTED" ]]

  # Should have minimal calls (1-2 is acceptable, >5 indicates recursion)
  [[ "$output" =~ "CALL_COUNT=" ]]
  local count=$(echo "$output" | grep -o 'CALL_COUNT=[0-9]*' | cut -d= -f2)
  [ "$count" -le 2 ]
}

@test "completion: service variable is set to git before calling _git" {
  # Verify the fix sets service=git to prevent recursion

  run zsh -c '
    source "'"${BATS_TEST_DIRNAME}"'/../dot_config/dd-git-tools.zsh"

    # Extract _gg function body and check for service=git
    functions _gg | grep -q "service=git"
    echo "service_set=$?"
  '

  [[ "$output" =~ "service_set=0" ]]
}

@test "completion: words[1] is set to git before calling _git" {
  # Verify words[1]=git is set

  run zsh -c '
    source "'"${BATS_TEST_DIRNAME}"'/../dot_config/dd-git-tools.zsh"

    # Extract _gg function body and check for words[1]=git
    functions _gg | grep -q "words\[1\]=git"
    echo "words_set=$?"
  '

  [[ "$output" =~ "words_set=0" ]]
}

# =============================================================================
# COMPLETION OUTPUT
# =============================================================================

@test "completion: gg commands include expected commands" {
  # Verify gg_commands array contains expected commands

  run zsh -c '
    source "'"${BATS_TEST_DIRNAME}"'/../dot_config/dd-git-tools.zsh"

    # Check that _gg contains expected commands in hardcoded list
    func_body=$(functions _gg)
    echo "$func_body" | grep -q "co:" && echo "has_co=yes" || echo "has_co=no"
    echo "$func_body" | grep -q "recent:" && echo "has_recent=yes" || echo "has_recent=no"
    echo "$func_body" | grep -q "checkpoint:" && echo "has_checkpoint=yes" || echo "has_checkpoint=no"
  '

  [[ "$output" =~ "has_co=yes" ]]
  [[ "$output" =~ "has_recent=yes" ]]
  [[ "$output" =~ "has_checkpoint=yes" ]]
}

@test "completion: curcontext is updated to git context" {
  # Verify curcontext is changed from gg to git to prevent recursion

  run zsh -c '
    source "'"${BATS_TEST_DIRNAME}"'/../dot_config/dd-git-tools.zsh"

    # Extract _gg function body and check for curcontext update
    functions _gg | grep -q "curcontext=.*gg.*git"
    echo "curcontext_updated=$?"
  '

  [[ "$output" =~ "curcontext_updated=0" ]]
}

@test "completion: compdef is registered without error" {
  # Verify compdef _gg gg works (the 2>/dev/null should suppress errors)

  run zsh -c '
    autoload -Uz compinit
    compinit -u 2>/dev/null

    source "'"${BATS_TEST_DIRNAME}"'/../dot_config/dd-git-tools.zsh"

    # Check if gg completion is registered
    if [[ -n "${_comps[gg]}" ]]; then
      echo "registered=yes"
    else
      echo "registered=no"
    fi
  '

  [ "$status" -eq 0 ]
  [[ "$output" =~ "registered=yes" ]]
}

# =============================================================================
# REGRESSION TESTS
# =============================================================================

@test "completion: does not break when completion system unavailable" {
  # Test the 2>/dev/null on compdef handles missing completion system

  run zsh -c '
    # Do NOT load compinit
    source "'"${BATS_TEST_DIRNAME}"'/../dot_config/dd-git-tools.zsh" 2>&1
    echo "loaded=yes"
  '

  [ "$status" -eq 0 ]
  [[ "$output" =~ "loaded=yes" ]]
}

@test "completion: _gg function exists after sourcing" {
  run zsh -c '
    autoload -Uz compinit
    compinit -u 2>/dev/null

    source "'"${BATS_TEST_DIRNAME}"'/../dot_config/dd-git-tools.zsh"

    if functions _gg > /dev/null 2>&1; then
      echo "exists=yes"
    else
      echo "exists=no"
    fi
  '

  [[ "$output" =~ "exists=yes" ]]
}
