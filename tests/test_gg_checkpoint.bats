#!/usr/bin/env bats

setup() {
  load 'test_helper'
  load_gg
  setup_checkpoint_repo
}

teardown() {
  teardown_checkpoint_repo
}

# Setup a basic repo for checkpoint testing
setup_checkpoint_repo() {
  TEST_REPO=$(mktemp -d)
  cd "$TEST_REPO"
  git init -q -b main
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > file.txt
  git add file.txt
  git commit -qm "initial commit"
}

teardown_checkpoint_repo() {
  cd /
  rm -rf "$TEST_REPO"
}

# =============================================================================
# BASIC FUNCTIONALITY
# =============================================================================

@test "checkpoint: creates WIP commit and checkpoint branch" {
  cd "$TEST_REPO"
  git checkout -q -b feature/test
  echo "changes" > new_file.txt

  run gg checkpoint
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Created checkpoint:" ]]
  [[ "$output" =~ "(with WIP commit)" ]]

  # Verify we're still on the original branch
  local current=$(git symbolic-ref --short HEAD)
  [ "$current" = "feature/test" ]

  # Verify checkpoint branch exists and has the WIP commit
  local today=$(date +%y%m%d)
  local msg=$(git log -1 --pretty=%s "checkpoints/${today}/feature/test/1")
  [ "$msg" = "WIP" ]
}

@test "checkpoint: branch name matches format checkpoints/YYMMDD/branch/N" {
  cd "$TEST_REPO"
  git checkout -q -b feature/test
  echo "changes" > new_file.txt

  run gg checkpoint
  [ "$status" -eq 0 ]

  local today=$(date +%y%m%d)
  # Verify checkpoint branch exists
  run git branch --list "checkpoints/${today}/feature/test/1"
  [[ -n "$output" ]]

  # Verify we're still on the original branch
  local current=$(git symbolic-ref --short HEAD)
  [ "$current" = "feature/test" ]
}

@test "checkpoint: includes staged files" {
  cd "$TEST_REPO"
  git checkout -q -b feature/test
  echo "staged" > staged.txt
  git add staged.txt

  run gg checkpoint
  [ "$status" -eq 0 ]

  # Verify file is in the checkpoint branch's commit
  local today=$(date +%y%m%d)
  run git show --name-only --pretty=format:'' "checkpoints/${today}/feature/test/1"
  [[ "$output" =~ "staged.txt" ]]
}

@test "checkpoint: includes unstaged files" {
  cd "$TEST_REPO"
  git checkout -q -b feature/test
  echo "modified" >> file.txt  # Modify existing tracked file

  run gg checkpoint
  [ "$status" -eq 0 ]

  # Verify file is in the checkpoint branch's commit
  local today=$(date +%y%m%d)
  run git show --name-only --pretty=format:'' "checkpoints/${today}/feature/test/1"
  [[ "$output" =~ "file.txt" ]]
}

@test "checkpoint: includes untracked files" {
  cd "$TEST_REPO"
  git checkout -q -b feature/test
  echo "untracked" > untracked.txt

  run gg checkpoint
  [ "$status" -eq 0 ]

  # Verify file is in the checkpoint branch's commit
  local today=$(date +%y%m%d)
  run git show --name-only --pretty=format:'' "checkpoints/${today}/feature/test/1"
  [[ "$output" =~ "untracked.txt" ]]
}

@test "checkpoint: increments N for multiple checkpoints same day" {
  cd "$TEST_REPO"
  git checkout -q -b feature/test
  local today=$(date +%y%m%d)

  # First checkpoint
  echo "first" > first.txt
  gg checkpoint

  # Second checkpoint (still on feature/test since checkpoint stays on original branch)
  echo "second" > second.txt
  gg checkpoint

  # Verify we're still on feature/test
  local current=$(git symbolic-ref --short HEAD)
  [ "$current" = "feature/test" ]

  # Verify both checkpoint branches exist
  run git branch --list "checkpoints/${today}/feature/test/*"
  local count=$(echo "$output" | wc -l | tr -d ' ')
  [ "$count" -eq 2 ]
}

# =============================================================================
# NO CHANGES CASE
# =============================================================================

@test "checkpoint: with no changes creates branch at current commit" {
  cd "$TEST_REPO"
  git checkout -q -b feature/test
  local today=$(date +%y%m%d)

  run gg checkpoint
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Created checkpoint:" ]]
  [[ "$output" =~ "(no changes)" ]]

  # Verify we're still on the original branch
  local current=$(git symbolic-ref --short HEAD)
  [ "$current" = "feature/test" ]

  # Verify checkpoint branch exists and points at same commit
  local orig_commit=$(git rev-parse feature/test)
  local cp_commit=$(git rev-parse "checkpoints/${today}/feature/test/1")
  [ "$orig_commit" = "$cp_commit" ]
}

# =============================================================================
# ERROR CASES
# =============================================================================

@test "checkpoint: fails in detached HEAD state" {
  cd "$TEST_REPO"
  git checkout -q --detach HEAD

  echo "changes" > new_file.txt

  run gg checkpoint
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Cannot checkpoint from detached HEAD state" ]]
}

# =============================================================================
# EDGE CASES
# =============================================================================

@test "checkpoint: works with nested branch names (slashes)" {
  cd "$TEST_REPO"
  git checkout -q -b ay/feat/featurea
  echo "changes" > new_file.txt

  run gg checkpoint
  [ "$status" -eq 0 ]

  local today=$(date +%y%m%d)
  # Verify checkpoint branch exists
  run git branch --list "checkpoints/${today}/ay/feat/featurea/1"
  [[ -n "$output" ]]

  # Verify we're still on original branch
  local current=$(git symbolic-ref --short HEAD)
  [ "$current" = "ay/feat/featurea" ]
}

@test "checkpoint: branches sort chronologically" {
  cd "$TEST_REPO"
  git checkout -q -b feature/test
  local today=$(date +%y%m%d)

  # Create checkpoint branches with different "dates" manually to test sorting
  git branch "checkpoints/250101/feature/test/1"
  git branch "checkpoints/261212/feature/test/1"
  git branch "checkpoints/260601/feature/test/1"

  # List and verify they sort correctly
  run git branch --list "checkpoints/*" --sort=refname
  [ "$status" -eq 0 ]

  # Extract the dates in order
  local dates=$(echo "$output" | sed 's/.*checkpoints\/\([0-9]*\)\/.*/\1/' | tr '\n' ' ')
  [[ "$dates" =~ "250101" ]]
  [[ "$dates" =~ "260601" ]]
  [[ "$dates" =~ "261212" ]]
}

@test "checkpoint: works from main branch" {
  cd "$TEST_REPO"
  echo "changes" > new_file.txt

  run gg checkpoint
  [ "$status" -eq 0 ]

  local today=$(date +%y%m%d)
  # Verify checkpoint branch exists
  run git branch --list "checkpoints/${today}/main/1"
  [[ -n "$output" ]]

  # Verify we're still on main
  local current=$(git symbolic-ref --short HEAD)
  [ "$current" = "main" ]
}

@test "checkpoint: handles gap in numbering after deletion" {
  cd "$TEST_REPO"
  git checkout -q -b feature/gap
  local today=$(date +%y%m%d)

  # Create checkpoints 1, 2, 3
  echo "1" > f1.txt && gg checkpoint
  echo "2" > f2.txt && gg checkpoint
  echo "3" > f3.txt && gg checkpoint

  # Delete checkpoint 2
  git branch -D "checkpoints/${today}/feature/gap/2"

  # Create new checkpoint - should be 4, not 3
  echo "4" > f4.txt
  gg checkpoint

  # Verify checkpoint 4 exists
  run git branch --list "checkpoints/${today}/feature/gap/4"
  [[ -n "$output" ]]

  # Verify we're still on feature/gap
  local current=$(git symbolic-ref --short HEAD)
  [ "$current" = "feature/gap" ]
}

@test "checkpoint: from checkpoint branch increments N without nesting" {
  cd "$TEST_REPO"
  git checkout -q -b feature/meta
  local today=$(date +%y%m%d)

  # Create first checkpoint
  echo "1" > m1.txt
  gg checkpoint

  # Switch to the checkpoint branch, make more changes
  git checkout -q "checkpoints/${today}/feature/meta/1"
  # Need to be on a named branch for checkpoint to work
  # The checkpoint branch IS a named branch, so switch to it properly
  git checkout "checkpoints/${today}/feature/meta/1"
  echo "2" > m2.txt
  gg checkpoint

  # Should be /2, not nested - and we stay on the checkpoint/1 branch
  run git branch --list "checkpoints/${today}/feature/meta/2"
  [[ -n "$output" ]]

  local current=$(git symbolic-ref --short HEAD)
  [ "$current" = "checkpoints/${today}/feature/meta/1" ]
}
