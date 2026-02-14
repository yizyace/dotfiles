#!/usr/bin/env bats

setup() {
  load 'test_helper'
  load_gg
  setup_checkpoints_repo
}

teardown() {
  teardown_checkpoints_repo
}

setup_checkpoints_repo() {
  TEST_REPO=$(mktemp -d)
  cd "$TEST_REPO"
  git init -q -b main
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > file.txt
  git add file.txt
  git commit -qm "initial commit"
}

teardown_checkpoints_repo() {
  cd /
  rm -rf "$TEST_REPO"
}

# =============================================================================
# BASIC OUTPUT
# =============================================================================

@test "checkpoints: shows checkpoint branches grouped by date" {
  cd "$TEST_REPO"
  git branch "checkpoints/260214/feature-test/1"
  git branch "checkpoints/260214/feature-test/2"

  run gg checkpoints
  [ "$status" -eq 0 ]
  [[ "$output" =~ "── 26-02-14 ──" ]]
  [[ "$output" =~ "feature-test - 1" ]]
  [[ "$output" =~ "feature-test - 2" ]]
}

@test "checkpoints: display format shows branch-name - N not full path" {
  cd "$TEST_REPO"
  git branch "checkpoints/260214/my-feature/3"

  run gg checkpoints
  [ "$status" -eq 0 ]
  [[ "$output" =~ "my-feature - 3" ]]
  # Should NOT show the full path
  [[ ! "$output" =~ "checkpoints/260214/my-feature/3" ]]
}

@test "checkpoints: empty state shows message" {
  cd "$TEST_REPO"

  run gg checkpoints
  [ "$status" -eq 0 ]
  [[ "$output" =~ "No checkpoints found." ]]
}

# =============================================================================
# LIMITS
# =============================================================================

@test "checkpoints: default limits to 3 dates" {
  cd "$TEST_REPO"
  git branch "checkpoints/260201/feat/1"
  git branch "checkpoints/260202/feat/1"
  git branch "checkpoints/260203/feat/1"
  git branch "checkpoints/260204/feat/1"

  run gg checkpoints
  [ "$status" -eq 0 ]
  # Newest 3 dates shown (260204, 260203, 260202)
  [[ "$output" =~ "── 26-02-04 ──" ]]
  [[ "$output" =~ "── 26-02-03 ──" ]]
  [[ "$output" =~ "── 26-02-02 ──" ]]
  # Oldest date not shown
  [[ ! "$output" =~ "── 26-02-01 ──" ]]
}

@test "checkpoints: limits to 3 checkpoints per date" {
  cd "$TEST_REPO"
  git branch "checkpoints/260214/feat/1"
  git branch "checkpoints/260214/feat/2"
  git branch "checkpoints/260214/feat/3"
  git branch "checkpoints/260214/feat/4"

  run gg checkpoints
  [ "$status" -eq 0 ]
  # Sorted newest-first by refname, so 4,3,2 shown, 1 not
  [[ "$output" =~ "feat - 4" ]]
  [[ "$output" =~ "feat - 3" ]]
  [[ "$output" =~ "feat - 2" ]]
  [[ ! "$output" =~ "feat - 1" ]]
}

# =============================================================================
# N ARGUMENT
# =============================================================================

@test "checkpoints: N argument controls number of dates shown" {
  cd "$TEST_REPO"
  git branch "checkpoints/260201/feat/1"
  git branch "checkpoints/260202/feat/1"
  git branch "checkpoints/260203/feat/1"

  run gg checkpoints 1
  [ "$status" -eq 0 ]
  [[ "$output" =~ "── 26-02-03 ──" ]]
  [[ ! "$output" =~ "── 26-02-02 ──" ]]
  [[ ! "$output" =~ "── 26-02-01 ──" ]]
}

@test "checkpoints: N=5 shows up to 5 dates" {
  cd "$TEST_REPO"
  git branch "checkpoints/260201/feat/1"
  git branch "checkpoints/260202/feat/1"
  git branch "checkpoints/260203/feat/1"
  git branch "checkpoints/260204/feat/1"
  git branch "checkpoints/260205/feat/1"

  run gg checkpoints 5
  [ "$status" -eq 0 ]
  [[ "$output" =~ "── 26-02-05 ──" ]]
  [[ "$output" =~ "── 26-02-04 ──" ]]
  [[ "$output" =~ "── 26-02-03 ──" ]]
  [[ "$output" =~ "── 26-02-02 ──" ]]
  [[ "$output" =~ "── 26-02-01 ──" ]]
}

# =============================================================================
# ORDERING
# =============================================================================

@test "checkpoints: newest date first" {
  cd "$TEST_REPO"
  git branch "checkpoints/260101/feat/1"
  git branch "checkpoints/260301/feat/1"
  git branch "checkpoints/260201/feat/1"

  run gg checkpoints
  [ "$status" -eq 0 ]

  # Check that 260301 appears before 260201 which appears before 260101
  local pos_03=$(echo "$output" | grep -n "26-03-01" | head -1 | cut -d: -f1)
  local pos_02=$(echo "$output" | grep -n "26-02-01" | head -1 | cut -d: -f1)
  local pos_01=$(echo "$output" | grep -n "26-01-01" | head -1 | cut -d: -f1)
  [ "$pos_03" -lt "$pos_02" ]
  [ "$pos_02" -lt "$pos_01" ]
}

@test "checkpoints: newest checkpoint first within date" {
  cd "$TEST_REPO"
  git branch "checkpoints/260214/feat/1"
  git branch "checkpoints/260214/feat/2"
  git branch "checkpoints/260214/feat/3"

  run gg checkpoints
  [ "$status" -eq 0 ]

  # 3 should appear before 2 which should appear before 1
  local pos_3=$(echo "$output" | grep -n "feat - 3" | head -1 | cut -d: -f1)
  local pos_2=$(echo "$output" | grep -n "feat - 2" | head -1 | cut -d: -f1)
  local pos_1=$(echo "$output" | grep -n "feat - 1" | head -1 | cut -d: -f1)
  [ "$pos_3" -lt "$pos_2" ]
  [ "$pos_2" -lt "$pos_1" ]
}

# =============================================================================
# INTERACTIVE MODE
# =============================================================================

@test "checkpoints: -i flag triggers interactive mode" {
  cd "$TEST_REPO"
  git branch "checkpoints/260214/feat/1"

  run bash -c 'PATH="/usr/bin:/bin" && source "'"${BATS_TEST_DIRNAME}"'/../dot_config/dd-git-tools.zsh" 2>/dev/null && gg checkpoints -i'

  [ "$status" -eq 1 ]
  [[ "$output" =~ "fzf is required" ]]
}

@test "checkpoints: --interactive flag works same as -i" {
  cd "$TEST_REPO"
  git branch "checkpoints/260214/feat/1"

  run bash -c 'PATH="/usr/bin:/bin" && source "'"${BATS_TEST_DIRNAME}"'/../dot_config/dd-git-tools.zsh" 2>/dev/null && gg checkpoints --interactive'

  [ "$status" -eq 1 ]
  [[ "$output" =~ "fzf is required" ]]
}

@test "checkpoints: N before -i flag works" {
  cd "$TEST_REPO"
  git branch "checkpoints/260214/feat/1"

  run bash -c 'PATH="/usr/bin:/bin" && source "'"${BATS_TEST_DIRNAME}"'/../dot_config/dd-git-tools.zsh" 2>/dev/null && gg checkpoints 2 -i'

  [ "$status" -eq 1 ]
  [[ "$output" =~ "fzf is required" ]]
}

@test "checkpoints: -i before N flag works" {
  cd "$TEST_REPO"
  git branch "checkpoints/260214/feat/1"

  run bash -c 'PATH="/usr/bin:/bin" && source "'"${BATS_TEST_DIRNAME}"'/../dot_config/dd-git-tools.zsh" 2>/dev/null && gg checkpoints -i 2'

  [ "$status" -eq 1 ]
  [[ "$output" =~ "fzf is required" ]]
}

@test "checkpoints: fallback when fzf missing shows install hint" {
  cd "$TEST_REPO"
  git branch "checkpoints/260214/feat/1"

  run bash -c 'PATH="/usr/bin:/bin" && source "'"${BATS_TEST_DIRNAME}"'/../dot_config/dd-git-tools.zsh" 2>/dev/null && gg checkpoints -i'

  [[ "$output" =~ "brew install fzf" ]]
}

@test "checkpoints: fallback when fzf missing still shows branches" {
  cd "$TEST_REPO"
  git branch "checkpoints/260214/feat/1"

  run bash -c 'PATH="/usr/bin:/bin" && source "'"${BATS_TEST_DIRNAME}"'/../dot_config/dd-git-tools.zsh" 2>/dev/null && gg checkpoints -i'

  [[ "$output" =~ "Falling back to list mode" ]]
  [[ "$output" =~ "feat - 1" ]]
}

# =============================================================================
# EDGE CASES
# =============================================================================

@test "checkpoints: handles nested branch names with slashes" {
  cd "$TEST_REPO"
  git branch "checkpoints/260214/feature/nested/branch/1"

  run gg checkpoints
  [ "$status" -eq 0 ]
  [[ "$output" =~ "feature/nested/branch - 1" ]]
}

@test "checkpoints: multiple source branches under same date" {
  cd "$TEST_REPO"
  git branch "checkpoints/260214/feature-a/1"
  git branch "checkpoints/260214/feature-b/1"
  git branch "checkpoints/260214/feature-b/2"

  run gg checkpoints
  [ "$status" -eq 0 ]
  [[ "$output" =~ "── 26-02-14 ──" ]]
  [[ "$output" =~ "feature-a - 1" ]]
  [[ "$output" =~ "feature-b - 1" ]]
  [[ "$output" =~ "feature-b - 2" ]]
}

# =============================================================================
# HELP
# =============================================================================

@test "checkpoints: command appears in gg help output" {
  run bash -c 'source "'"${BATS_TEST_DIRNAME}"'/../dot_config/dd-git-tools.zsh" 2>/dev/null && gg help'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "checkpoints" ]]
  [[ "$output" =~ "list checkpoints" ]]
}
