#!/usr/bin/env bats

# Tests for the Claude Code Stop hook notification script

SCRIPT_PATH="${BATS_TEST_DIRNAME}/../dot_claude/hooks/executable_notify-done.sh"

setup() {
  TEST_DIR=$(mktemp -d)

  # Create mock binaries that log calls
  mkdir -p "$TEST_DIR/bin"

  cat > "$TEST_DIR/bin/afplay" <<'SCRIPT'
#!/usr/bin/env bash
echo "afplay $*" >> "${NOTIFY_TEST_LOG}"
SCRIPT
  chmod +x "$TEST_DIR/bin/afplay"

  cat > "$TEST_DIR/bin/say" <<'SCRIPT'
#!/usr/bin/env bash
echo "say $*" >> "${NOTIFY_TEST_LOG}"
SCRIPT
  chmod +x "$TEST_DIR/bin/say"

  cat > "$TEST_DIR/bin/osascript" <<'SCRIPT'
#!/usr/bin/env bash
echo "osascript $*" >> "${NOTIFY_TEST_LOG}"
SCRIPT
  chmod +x "$TEST_DIR/bin/osascript"

  cat > "$TEST_DIR/bin/sleep" <<'SCRIPT'
#!/usr/bin/env bash
echo "sleep $*" >> "${NOTIFY_TEST_LOG}"
SCRIPT
  chmod +x "$TEST_DIR/bin/sleep"

  export PATH="$TEST_DIR/bin:$PATH"
  export NOTIFY_TEST_LOG="$TEST_DIR/calls.log"
  touch "$NOTIFY_TEST_LOG"

  source "$SCRIPT_PATH"
}

teardown() {
  cd /
  rm -rf "$TEST_DIR"
}

# =============================================================================
# JSON PARSING
# =============================================================================

@test "parse_cwd_from_json: extracts cwd from valid JSON" {
  run parse_cwd_from_json '{"cwd": "/Users/me/project", "session_id": "abc"}'
  [ "$status" -eq 0 ]
  [ "$output" = "/Users/me/project" ]
}

@test "parse_cwd_from_json: handles cwd with spaces in path" {
  run parse_cwd_from_json '{"cwd": "/Users/me/my project"}'
  [ "$status" -eq 0 ]
  [ "$output" = "/Users/me/my project" ]
}

@test "parse_cwd_from_json: handles no space after colon" {
  run parse_cwd_from_json '{"cwd":"/tmp/test"}'
  [ "$status" -eq 0 ]
  [ "$output" = "/tmp/test" ]
}

@test "parse_cwd_from_json: returns error when cwd missing" {
  run parse_cwd_from_json '{"session_id": "abc"}'
  [ "$status" -eq 1 ]
}

@test "parse_cwd_from_json: returns error on empty string" {
  run parse_cwd_from_json ''
  [ "$status" -eq 1 ]
}

@test "parse_cwd_from_json: handles full hook payload" {
  local json='{"session_id":"s1","transcript_path":"/tmp/t","cwd":"/Users/me/code","permission_mode":"default","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"Done."}'
  run parse_cwd_from_json "$json"
  [ "$status" -eq 0 ]
  [ "$output" = "/Users/me/code" ]
}

@test "parse_cwd_from_json: handles cwd not at start of JSON" {
  run parse_cwd_from_json '{"other": "value", "cwd": "/my/path"}'
  [ "$status" -eq 0 ]
  [ "$output" = "/my/path" ]
}

# =============================================================================
# GIT BRANCH DETECTION
# =============================================================================

@test "get_git_branch: returns current branch name" {
  local repo=$(mktemp -d)
  cd "$repo"
  git init -q -b main
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "init" > f.txt && git add f.txt && git commit -qm "init"
  git checkout -q -b feature-xyz

  run get_git_branch "$repo"
  [ "$status" -eq 0 ]
  [ "$output" = "feature-xyz" ]

  cd /
  rm -rf "$repo"
}

@test "get_git_branch: returns 'no branch' in detached HEAD" {
  local repo=$(mktemp -d)
  cd "$repo"
  git init -q -b main
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "init" > f.txt && git add f.txt && git commit -qm "init"
  git checkout -q --detach HEAD

  run get_git_branch "$repo"
  [ "$status" -eq 0 ]
  [ "$output" = "no branch" ]

  cd /
  rm -rf "$repo"
}

@test "get_git_branch: returns 'no branch' for non-git directory" {
  local non_git=$(mktemp -d)

  run get_git_branch "$non_git"
  [ "$status" -eq 0 ]
  [ "$output" = "no branch" ]

  rm -rf "$non_git"
}

@test "get_git_branch: handles branch with slashes" {
  local repo=$(mktemp -d)
  cd "$repo"
  git init -q -b main
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "init" > f.txt && git add f.txt && git commit -qm "init"
  git checkout -q -b feature/nested/branch

  run get_git_branch "$repo"
  [ "$status" -eq 0 ]
  [ "$output" = "feature/nested/branch" ]

  cd /
  rm -rf "$repo"
}

# =============================================================================
# WORKTREE DETECTION
# =============================================================================

@test "is_git_worktree: returns false for main working tree" {
  local repo=$(mktemp -d)
  cd "$repo"
  git init -q -b main
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "init" > f.txt && git add f.txt && git commit -qm "init"

  run is_git_worktree "$repo"
  [ "$status" -eq 1 ]

  cd /
  rm -rf "$repo"
}

@test "is_git_worktree: returns true for a worktree" {
  local repo=$(mktemp -d)
  local wt=$(mktemp -d)
  cd "$repo"
  git init -q -b main
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "init" > f.txt && git add f.txt && git commit -qm "init"
  git branch feature-wt
  git worktree add "$wt" feature-wt -q

  run is_git_worktree "$wt"
  [ "$status" -eq 0 ]

  cd /
  git -C "$repo" worktree remove "$wt" --force 2>/dev/null || true
  rm -rf "$repo" "$wt"
}

@test "is_git_worktree: returns false for non-git directory" {
  local non_git=$(mktemp -d)

  run is_git_worktree "$non_git"
  [ "$status" -eq 1 ]

  rm -rf "$non_git"
}

# =============================================================================
# PROJECT NAME RESOLUTION
# =============================================================================

@test "get_project_name: returns repo dir name from main working tree" {
  local repo=$(mktemp -d)
  cd "$repo"
  git init -q -b main
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "init" > f.txt && git add f.txt && git commit -qm "init"

  run get_project_name "$repo"
  [ "$status" -eq 0 ]
  [ "$output" = "$(basename "$repo")" ]

  cd /
  rm -rf "$repo"
}

@test "get_project_name: returns main repo dir name from worktree" {
  local repo=$(mktemp -d)
  local wt=$(mktemp -d)
  cd "$repo"
  git init -q -b main
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "init" > f.txt && git add f.txt && git commit -qm "init"
  git branch feat
  git worktree add "$wt" feat -q

  run get_project_name "$wt"
  [ "$status" -eq 0 ]
  [ "$output" = "$(basename "$repo")" ]

  cd /
  git -C "$repo" worktree remove "$wt" --force 2>/dev/null || true
  rm -rf "$repo" "$wt"
}

@test "get_project_name: falls back to basename for non-git dir" {
  local non_git=$(mktemp -d)

  run get_project_name "$non_git"
  [ "$status" -eq 0 ]
  [ "$output" = "$(basename "$non_git")" ]

  rm -rf "$non_git"
}

# =============================================================================
# NOTIFICATION SEQUENCE — NON-WORKTREE
# =============================================================================

@test "play_notification: plays Glass, says project, says branch when not worktree" {
  play_notification "/Users/me/project" "main" "false"

  run cat "$NOTIFY_TEST_LOG"
  local lines
  IFS=$'\n' read -r -d '' -a lines <<< "$output" || true

  [[ "${lines[0]}" == *"afplay /System/Library/Sounds/Glass.aiff"* ]]
  [[ "${lines[1]}" == "say project" ]]
  [[ "${lines[2]}" == "say main" ]]
  [[ "${lines[3]}" == *"osascript"* ]]
}

@test "play_notification: non-worktree has 4 calls total" {
  play_notification "/Users/me/project" "main" "false"

  run cat "$NOTIFY_TEST_LOG"
  local line_count
  line_count=$(echo "$output" | wc -l | tr -d ' ')
  [ "$line_count" -eq 4 ]
}

@test "play_notification: non-worktree notification shows project / branch" {
  play_notification "/Users/me/myproject" "feature-x" "false"

  run cat "$NOTIFY_TEST_LOG"
  [[ "$output" == *"myproject / feature-x"* ]]
}

# =============================================================================
# NOTIFICATION SEQUENCE — WORKTREE
# =============================================================================

@test "play_notification: full worktree sequence with project, worktree, branch" {
  play_notification "/Users/me/worktrees/my-worktree" "feature-a" "true"

  run cat "$NOTIFY_TEST_LOG"
  local lines
  IFS=$'\n' read -r -d '' -a lines <<< "$output" || true

  [[ "${lines[0]}" == *"afplay /System/Library/Sounds/Glass.aiff"* ]]
  [[ "${lines[1]}" == "say my-worktree" ]]
  [[ "${lines[2]}" == "say my-worktree" ]]
  [[ "${lines[3]}" == "sleep 0.3" ]]
  [[ "${lines[4]}" == "say feature-a" ]]
  [[ "${lines[5]}" == *"osascript"* ]]
}

@test "play_notification: worktree sequence has 6 calls total" {
  play_notification "/tmp/wt-dir" "develop" "true"

  run cat "$NOTIFY_TEST_LOG"
  local line_count
  line_count=$(echo "$output" | wc -l | tr -d ' ')
  [ "$line_count" -eq 6 ]
}

@test "play_notification: worktree notification shows project / worktree / branch" {
  play_notification "/Users/me/worktrees/my-worktree" "feature-a" "true"

  run cat "$NOTIFY_TEST_LOG"
  # get_project_name falls back to basename on non-git path, so project = worktree name here
  [[ "$output" == *"my-worktree / my-worktree / feature-a"* ]]
}

# =============================================================================
# INTEGRATION VIA STDIN
# =============================================================================

@test "main: full pipeline with non-worktree repo" {
  local repo=$(mktemp -d)
  cd "$repo"
  git init -q -b develop
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "init" > f.txt && git add f.txt && git commit -qm "init"

  echo "{\"cwd\": \"$repo\", \"session_id\": \"s1\"}" | main

  run cat "$NOTIFY_TEST_LOG"
  [[ "$output" == *"afplay"* ]]
  [[ "$output" == *"say develop"* ]]
  # 4 calls: afplay, say project, say branch, osascript
  local line_count
  line_count=$(echo "$output" | wc -l | tr -d ' ')
  [ "$line_count" -eq 4 ]

  cd /
  rm -rf "$repo"
}

@test "main: full pipeline with worktree" {
  local repo=$(mktemp -d)
  local wt_parent=$(mktemp -d)
  local wt="$wt_parent/my-feature-wt"
  cd "$repo"
  git init -q -b main
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "init" > f.txt && git add f.txt && git commit -qm "init"
  git branch feature-wt
  git worktree add "$wt" feature-wt -q

  echo "{\"cwd\": \"$wt\", \"session_id\": \"s1\"}" | main

  run cat "$NOTIFY_TEST_LOG"
  [[ "$output" == *"afplay"* ]]
  [[ "$output" == *"say my-feature-wt"* ]]
  [[ "$output" == *"sleep 0.3"* ]]
  [[ "$output" == *"say feature-wt"* ]]
  # 6 calls: afplay, say project, say worktree, sleep, say branch, osascript
  local line_count
  line_count=$(echo "$output" | wc -l | tr -d ' ')
  [ "$line_count" -eq 6 ]

  cd /
  git -C "$repo" worktree remove "$wt" --force 2>/dev/null || true
  rm -rf "$repo" "$wt_parent"
}

@test "main: exits with error on JSON without cwd" {
  run bash -c 'echo "{\"no_cwd\": true}" | (source "'"$SCRIPT_PATH"'" && main)'
  [ "$status" -eq 1 ]
}
