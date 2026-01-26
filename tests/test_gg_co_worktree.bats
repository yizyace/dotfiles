#!/usr/bin/env bats

setup() {
  load 'test_helper'
  load_gg
  setup_repo_with_worktree
}

teardown() {
  teardown_repo_with_worktree
}

# =============================================================================
# CORE WORKTREE FEATURE
# =============================================================================

@test "co: branch in worktree triggers auto-cd" {
  cd "$TEST_REPO"
  run gg co feature-a
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Branch is in worktree:" ]]
  # Verify we're now in the worktree (check pwd in subshell)
  [[ "$output" =~ "$TEST_WORKTREE" ]]
}

@test "co: normal checkout when branch not in worktree" {
  cd "$TEST_REPO"
  run gg co feature/nested
  [ "$status" -eq 0 ]
  run git branch --show-current
  [ "$output" = "feature/nested" ]
}

@test "co: already in target worktree shows 'Already on'" {
  cd "$TEST_WORKTREE"
  run gg co feature-a
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Already on" ]]
}

# =============================================================================
# FLAG PASSTHROUGH
# =============================================================================

@test "co: -b flag creates new branch" {
  cd "$TEST_REPO"
  run gg co -b new-test-branch
  [ "$status" -eq 0 ]
  run git branch --show-current
  [ "$output" = "new-test-branch" ]
}

@test "co: --help shows git checkout help" {
  cd "$TEST_REPO"
  run gg co --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "git-checkout" ]] || [[ "$output" =~ "usage:" ]]
}

@test "co: -q flag passes through (quiet mode)" {
  cd "$TEST_REPO"
  run gg co -q feature/nested
  [ "$status" -eq 0 ]
  # Output should be empty in quiet mode
  [ -z "$output" ]
}

# =============================================================================
# NO ARGUMENTS / SPECIAL ARGS
# =============================================================================

@test "co: no args shows checkout info" {
  cd "$TEST_REPO"
  echo "modified" >> file.txt
  run gg co
  # Should show modified file status
  [[ "$output" =~ "file.txt" ]] || [[ "$output" =~ "M" ]]
}

@test "co: dot restores working tree" {
  cd "$TEST_REPO"
  echo "modified" >> file.txt
  gg co .
  run cat file.txt
  [ "$output" = "initial" ]
}

@test "co: -- file.txt restores specific file" {
  cd "$TEST_REPO"
  echo "modified" >> file.txt
  gg co -- file.txt
  run cat file.txt
  [ "$output" = "initial" ]
}

# =============================================================================
# TAGS, HASHES, REFS
# =============================================================================

@test "co: checkout tag works" {
  cd "$TEST_REPO"
  git tag v1.0.0
  run gg co v1.0.0
  [ "$status" -eq 0 ]
  [[ "$output" =~ "detached HEAD" ]] || [[ "$output" =~ "HEAD is now" ]]
}

@test "co: checkout commit hash works" {
  cd "$TEST_REPO"
  local hash=$(git rev-parse --short HEAD)
  run gg co "$hash"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "detached HEAD" ]] || [[ "$output" =~ "HEAD is now" ]]
}

@test "co: checkout HEAD~1 works" {
  cd "$TEST_REPO"
  echo "second" > file2.txt && git add . && git commit -qm "second"
  run gg co HEAD~1
  [ "$status" -eq 0 ]
  [[ "$output" =~ "detached HEAD" ]] || [[ "$output" =~ "HEAD is now" ]]
}

# =============================================================================
# ERROR CASES
# =============================================================================

@test "co: non-existent branch shows error" {
  cd "$TEST_REPO"
  run gg co nonexistent-branch-xyz
  [ "$status" -ne 0 ]
  [[ "$output" =~ "error" ]] || [[ "$output" =~ "did not match" ]]
}

@test "co: partial branch name shows error" {
  cd "$TEST_REPO"
  run gg co feature-
  [ "$status" -ne 0 ]
}

@test "co: in non-git directory shows error" {
  cd /tmp
  run gg co main
  [ "$status" -ne 0 ]
  [[ "$output" =~ "not a git repository" ]]
}

# =============================================================================
# BRANCH NAME EDGE CASES
# =============================================================================

@test "co: branch with slashes works" {
  cd "$TEST_REPO"
  run gg co feature/nested
  [ "$status" -eq 0 ]
  run git branch --show-current
  [ "$output" = "feature/nested" ]
}

@test "co: branch with slashes in worktree triggers auto-cd" {
  cd "$TEST_REPO"
  # Remove existing worktree and create one with nested branch
  git worktree remove "$TEST_WORKTREE" --force 2>/dev/null || true
  git worktree add "$TEST_WORKTREE" feature/nested -q
  run gg co feature/nested
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Branch is in worktree:" ]]
}

@test "co: branch name starting with hyphen treated as flag" {
  cd "$TEST_REPO"
  run gg co -invalid-branch
  [ "$status" -ne 0 ]
  # Should be passed to git and fail as invalid flag
  [[ "$output" =~ "error" ]] || [[ "$output" =~ "unknown" ]]
}

# =============================================================================
# DIRECTORY CONTEXT
# =============================================================================

@test "co: from subdirectory still triggers worktree cd" {
  cd "$TEST_REPO"
  mkdir -p subdir
  cd subdir
  run gg co feature-a
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Branch is in worktree:" ]]
}

@test "co: from worktree subdirectory shows 'Already on'" {
  cd "$TEST_WORKTREE"
  mkdir -p subdir
  cd subdir
  run gg co feature-a
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Already on" ]]
}

# =============================================================================
# MULTIPLE ARGUMENTS
# =============================================================================

@test "co: branch and file args work (restore from branch)" {
  cd "$TEST_REPO"
  git checkout -q feature/nested
  echo "on nested" > file.txt
  git add . && git commit -qm "nested change"
  git checkout -q main
  run gg co feature/nested -- file.txt
  [ "$status" -eq 0 ]
  run cat file.txt
  [ "$output" = "on nested" ]
}
