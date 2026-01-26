#!/usr/bin/env bats

setup() {
  load 'test_helper'
  load_gg
  setup_repo_with_history
}

teardown() {
  teardown_repo_with_history
}

# Setup a repo with checkout history for testing recent
setup_repo_with_history() {
  TEST_REPO=$(mktemp -d)
  cd "$TEST_REPO"
  git init -q -b main
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > file.txt
  git add file.txt
  git commit -qm "initial commit"

  # Create branches and checkout to build reflog history
  git branch feature-a
  git branch feature-b
  git branch feature-c
  git checkout -q feature-a
  git checkout -q feature-b
  git checkout -q feature-c
  git checkout -q main
}

teardown_repo_with_history() {
  cd /
  rm -rf "$TEST_REPO"
}

# =============================================================================
# BASIC RECENT OUTPUT
# =============================================================================

@test "recent: lists recently visited branches" {
  cd "$TEST_REPO"
  run gg recent
  [ "$status" -eq 0 ]
  # Should show branches in reverse chronological order (most recent first)
  [[ "$output" =~ "main" ]]
  [[ "$output" =~ "feature-c" ]]
}

@test "recent: respects count argument" {
  cd "$TEST_REPO"
  run gg recent 2
  [ "$status" -eq 0 ]
  # Count lines - should be at most 2
  local line_count=$(echo "$output" | wc -l | tr -d ' ')
  [ "$line_count" -le 2 ]
}

@test "recent: deduplicates branches" {
  cd "$TEST_REPO"
  # Checkout feature-a multiple times
  git checkout -q feature-a
  git checkout -q main
  git checkout -q feature-a
  git checkout -q main

  run gg recent
  [ "$status" -eq 0 ]
  # Count occurrences of "main" - should be exactly 1
  local count=$(echo "$output" | grep -c "^main$" || true)
  [ "$count" -eq 1 ]
}

@test "recent: default count is 10" {
  cd "$TEST_REPO"
  # Create more branches and checkouts to exceed 10
  for i in {1..15}; do
    git branch "test-branch-$i" 2>/dev/null || true
    git checkout -q "test-branch-$i"
  done

  run gg recent
  [ "$status" -eq 0 ]
  local line_count=$(echo "$output" | wc -l | tr -d ' ')
  [ "$line_count" -eq 10 ]
}

# =============================================================================
# FLAG PARSING
# =============================================================================

@test "recent: -i flag triggers interactive mode check" {
  cd "$TEST_REPO"
  # Remove fzf from PATH temporarily to test fallback (use subshell to avoid leaking)
  run bash -c 'PATH="/usr/bin:/bin" && source "'"${BATS_TEST_DIRNAME}"'/../dot_config/dd-git-tools.zsh" 2>/dev/null && gg recent -i'

  # Should fail with error about fzf
  [ "$status" -eq 1 ]
  [[ "$output" =~ "fzf is required" ]]
}

@test "recent: --interactive flag works same as -i" {
  cd "$TEST_REPO"
  run bash -c 'PATH="/usr/bin:/bin" && source "'"${BATS_TEST_DIRNAME}"'/../dot_config/dd-git-tools.zsh" 2>/dev/null && gg recent --interactive'

  [ "$status" -eq 1 ]
  [[ "$output" =~ "fzf is required" ]]
}

@test "recent: -i with count argument works" {
  cd "$TEST_REPO"
  run bash -c 'PATH="/usr/bin:/bin" && source "'"${BATS_TEST_DIRNAME}"'/../dot_config/dd-git-tools.zsh" 2>/dev/null && gg recent -i 5'

  # Should still show fallback output
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Falling back to list mode" ]]
}

@test "recent: count before -i flag works" {
  cd "$TEST_REPO"
  run bash -c 'PATH="/usr/bin:/bin" && source "'"${BATS_TEST_DIRNAME}"'/../dot_config/dd-git-tools.zsh" 2>/dev/null && gg recent 5 -i'

  [ "$status" -eq 1 ]
  [[ "$output" =~ "fzf is required" ]]
}

# =============================================================================
# GRACEFUL FALLBACK
# =============================================================================

@test "recent: shows helpful error when fzf missing" {
  cd "$TEST_REPO"
  run bash -c 'PATH="/usr/bin:/bin" && source "'"${BATS_TEST_DIRNAME}"'/../dot_config/dd-git-tools.zsh" 2>/dev/null && gg recent -i'

  [[ "$output" =~ "brew install fzf" ]]
}

@test "recent: falls back to list mode when fzf missing" {
  cd "$TEST_REPO"
  run bash -c 'PATH="/usr/bin:/bin" && source "'"${BATS_TEST_DIRNAME}"'/../dot_config/dd-git-tools.zsh" 2>/dev/null && gg recent -i'

  # Should still show the branch list
  [[ "$output" =~ "Falling back to list mode" ]]
  [[ "$output" =~ "main" ]]
}

# =============================================================================
# ERROR CASES
# =============================================================================

# Note: "in non-git directory" test is covered in test_gg_co_worktree.bats
# and tests basic git behavior rather than our code

@test "recent: with no checkout history returns empty" {
  local empty_repo=$(mktemp -d)
  cd "$empty_repo"
  git init -q -b main
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > file.txt
  git add file.txt
  git commit -qm "initial commit"

  run gg recent
  [ "$status" -eq 0 ]
  # No checkouts means empty output
  [ -z "$output" ]

  cd /
  rm -rf "$empty_repo"
}

# =============================================================================
# OUTPUT ORDERING
# =============================================================================

@test "recent: most recent branch is first in output" {
  cd "$TEST_REPO"
  # The setup ends with checkout to main, so main should be first
  run gg recent
  [ "$status" -eq 0 ]

  # Get the first line
  local first_branch=$(echo "$output" | head -n 1)
  [ "$first_branch" = "main" ]
}

@test "recent: fallback respects count argument" {
  cd "$TEST_REPO"
  run bash -c 'PATH="/usr/bin:/bin" && source "'"${BATS_TEST_DIRNAME}"'/../dot_config/dd-git-tools.zsh" 2>/dev/null && gg recent -i 3'

  [ "$status" -eq 1 ]
  [[ "$output" =~ "Falling back to list mode" ]]

  # Count branch lines after the fallback message (should be exactly 3)
  # The output format is: error msg, install hint, empty line, fallback msg, then branches
  local branch_count=$(echo "$output" | grep -v "^Error:" | grep -v "^Install" | grep -v "^$" | grep -v "^Falling" | wc -l | tr -d ' ')
  [ "$branch_count" -eq 3 ]
}
