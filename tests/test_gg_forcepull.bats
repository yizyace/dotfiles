#!/usr/bin/env bats

setup() {
  load 'test_helper'
  setup_force_pull_repo
  load_gg
}

teardown() {
  teardown_force_pull_repo
}

# Setup a bare "origin" repo + local clone with tracking branch
setup_force_pull_repo() {
  TEST_ORIGIN=$(mktemp -d)
  TEST_REPO=$(mktemp -d)
  TEST_CLONE2=$(mktemp -d)

  # Create bare origin
  git init -q --bare "$TEST_ORIGIN"

  # Clone to local repo (suppress empty-repo warning)
  git clone -q "$TEST_ORIGIN" "$TEST_REPO" 2>/dev/null
  cd "$TEST_REPO"
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > file.txt
  git add file.txt
  git commit -qm "initial commit"
  git push -q origin main

  # Create a second clone for pushing ahead
  git clone -q "$TEST_ORIGIN" "$TEST_CLONE2"
  cd "$TEST_CLONE2"
  git config user.email "test@test.com"
  git config user.name "Test"

  cd "$TEST_REPO"
}

teardown_force_pull_repo() {
  cd /
  rm -rf "$TEST_ORIGIN" "$TEST_REPO" "$TEST_CLONE2"
}

# =============================================================================
# HAPPY PATH
# =============================================================================

@test "forcepull: resets local to match remote" {
  cd "$TEST_CLONE2"
  echo "remote change" > file.txt
  git add file.txt
  git commit -qm "remote update"
  git push -q origin main

  cd "$TEST_REPO"
  local before=$(git rev-parse HEAD)

  run gg forcepull
  [ "$status" -eq 0 ]

  local after=$(git rev-parse HEAD)
  [ "$before" != "$after" ]

  # Local should match origin/main
  local origin_head=$(git rev-parse origin/main)
  [ "$after" = "$origin_head" ]
}

@test "forcepull: discards local commits" {
  cd "$TEST_REPO"
  echo "local only" > local.txt
  git add local.txt
  git commit -qm "local commit"

  run gg forcepull
  [ "$status" -eq 0 ]

  # Local commit should be gone
  [ ! -f local.txt ]

  local head=$(git rev-parse HEAD)
  local origin_head=$(git rev-parse origin/main)
  [ "$head" = "$origin_head" ]
}

@test "forcepull: output messages include fetch and reset" {
  cd "$TEST_REPO"

  run gg forcepull
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Fetching from origin" ]]
  [[ "$output" =~ "Resetting 'main' to 'origin/main'" ]]
}

@test "forcepull: output includes WIP message when dirty" {
  cd "$TEST_REPO"
  echo "dirty" > file.txt

  run gg forcepull
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Saving uncommitted changes as WIP commit" ]]
  [[ "$output" =~ "Fetching from origin" ]]
  [[ "$output" =~ "Resetting 'main' to 'origin/main'" ]]
}

# =============================================================================
# ERROR CASES
# =============================================================================

@test "forcepull: fails in detached HEAD state" {
  cd "$TEST_REPO"
  git checkout -q --detach HEAD

  run gg forcepull
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Cannot forcepull in detached HEAD state" ]]
}

@test "forcepull: fails with no upstream configured" {
  cd "$TEST_REPO"
  git checkout -q -b no-upstream

  run gg forcepull
  [ "$status" -eq 1 ]
  [[ "$output" =~ "No upstream tracking branch configured for 'no-upstream'" ]]
  [[ "$output" =~ "Hint: run" ]]
}

@test "forcepull: fails when fetch fails due to bad remote" {
  cd "$TEST_REPO"
  # Point upstream to a nonexistent remote
  git remote remove origin
  git remote add origin /nonexistent/path
  git config branch.main.remote origin
  git config branch.main.merge refs/heads/main

  run gg forcepull
  [ "$status" -eq 1 ]
  local expected="Error: fetch from"
  [[ "$output" =~ $expected ]]
}

# =============================================================================
# EDGE CASES
# =============================================================================

@test "forcepull: works with slashed branch names" {
  cd "$TEST_REPO"
  git checkout -q -b ay/feat/featureA
  git push -q -u origin ay/feat/featureA

  # Push a change from clone2
  cd "$TEST_CLONE2"
  git fetch -q origin
  git checkout -q -b ay/feat/featureA origin/ay/feat/featureA
  echo "remote change" > feature.txt
  git add feature.txt
  git commit -qm "feature update"
  git push -q origin ay/feat/featureA

  cd "$TEST_REPO"
  run gg forcepull
  [ "$status" -eq 0 ]

  # Should have the remote change
  [ -f feature.txt ]
  [ "$(cat feature.txt)" = "remote change" ]
}

@test "forcepull: dirty working tree saves WIP and is wiped by hard reset" {
  cd "$TEST_REPO"
  echo "dirty" > file.txt

  run gg forcepull
  [ "$status" -eq 0 ]

  # Dirty change should be gone
  [ "$(cat file.txt)" = "initial" ]

  # WIP commit should be in the reflog
  run git reflog show --format='%gs'
  [[ "$output" =~ "commit: WIP (forcepull)" ]]
}

@test "forcepull: saves staged and untracked files in WIP commit" {
  cd "$TEST_REPO"
  echo "staged" > staged.txt
  git add staged.txt
  echo "untracked" > untracked.txt

  run gg forcepull
  [ "$status" -eq 0 ]

  # Both files should be gone after reset
  [ ! -f staged.txt ]
  [ ! -f untracked.txt ]

  # WIP commit should contain both files
  local wip_sha
  wip_sha=$(git reflog --format='%H %gs' | grep 'WIP (forcepull)' | head -1 | cut -d' ' -f1)
  run git show --name-only --pretty=format:'' "$wip_sha"
  [[ "$output" =~ "staged.txt" ]]
  [[ "$output" =~ "untracked.txt" ]]
}

@test "forcepull: no WIP commit when working tree is clean" {
  cd "$TEST_REPO"

  run gg forcepull
  [ "$status" -eq 0 ]

  # No WIP commit in reflog
  run git reflog show --format='%gs'
  ! [[ "$output" =~ "WIP (forcepull)" ]]
}
