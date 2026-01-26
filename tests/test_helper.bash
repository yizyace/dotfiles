# Test helper functions for gg command tests

# Load the gg function
load_gg() {
  # Source from repo if running in CI, otherwise from installed location
  local script_path
  if [[ -f "${BATS_TEST_DIRNAME}/../dot_config/dd-git-tools.zsh" ]]; then
    script_path="${BATS_TEST_DIRNAME}/../dot_config/dd-git-tools.zsh"
  else
    script_path=~/.config/dd-git-tools.zsh
  fi
  # Source the file with set +e to handle unalias failure in bash
  set +e
  source "$script_path"
  set -e
}

# Setup a repo with a worktree
setup_repo_with_worktree() {
  TEST_REPO=$(mktemp -d)
  TEST_WORKTREE=$(mktemp -d)
  cd "$TEST_REPO"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > file.txt
  git add file.txt
  git commit -qm "initial commit"
  git branch feature-a
  git branch "feature/nested"
  git worktree add "$TEST_WORKTREE" feature-a -q
}

teardown_repo_with_worktree() {
  cd /
  rm -rf "$TEST_REPO" "$TEST_WORKTREE"
}
