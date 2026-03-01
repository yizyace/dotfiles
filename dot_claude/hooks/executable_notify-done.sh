#!/bin/bash
# =============================================================================
# Claude Code Stop Hook — Audible + Visual Notification
# =============================================================================
#
# Triggered by Claude Code's Stop hook after every assistant turn.
# Reads a JSON payload from stdin containing session metadata, then:
#
#   1. Extracts the working directory (cwd) from the JSON payload
#   2. Determines the current git branch and whether cwd is a git worktree
#   3. Resolves the project name (main repo directory)
#   4. Plays the Glass system sound
#   5. Speaks: project name → [worktree name →] branch name
#   6. Shows a macOS notification: "project / [worktree /] branch"
#
# Audio sequence (sequential so sounds don't overlap):
#   Glass.aiff → say project → [say worktree → 0.3s pause] → say branch
#
# Stdin JSON shape (Stop event):
#   {
#     "session_id": "...",
#     "transcript_path": "...",
#     "cwd": "...",
#     "permission_mode": "default|plan|acceptEdits|dontAsk|bypassPermissions",
#     "hook_event_name": "Stop",
#     "stop_hook_active": false,
#     "last_assistant_message": "..."
#   }
#
# Dependencies: bash, git, afplay, say, osascript (all standard on macOS)
# =============================================================================

# ---------------------------------------------------------------------------
# parse_cwd_from_json <json_string>
#   Extracts the "cwd" value from a JSON string using bash regex.
#   Prints the extracted path to stdout. Returns 1 if not found.
# ---------------------------------------------------------------------------
parse_cwd_from_json() {
  local json="$1"
  if [[ "$json" =~ \"cwd\":\ *\"([^\"]+)\" ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# get_git_branch <dir>
#   Prints the current git branch for the given directory.
#   Falls back to "no branch" if not in a git repo or in detached HEAD.
# ---------------------------------------------------------------------------
get_git_branch() {
  local dir="$1"
  local branch
  branch=$(git -C "$dir" branch --show-current 2>/dev/null)
  if [[ -z "$branch" ]]; then
    echo "no branch"
  else
    echo "$branch"
  fi
}

# ---------------------------------------------------------------------------
# is_git_worktree <dir>
#   Returns 0 (true) if dir is a git worktree (not the main working tree).
#   Returns 1 (false) if it's the main working tree or not a git repo.
# ---------------------------------------------------------------------------
is_git_worktree() {
  local dir="$1"
  local git_dir git_common_dir
  git_dir=$(git -C "$dir" rev-parse --git-dir 2>/dev/null) || return 1
  git_common_dir=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null) || return 1
  git_dir=$(cd "$dir" && cd "$git_dir" && pwd)
  git_common_dir=$(cd "$dir" && cd "$git_common_dir" && pwd)
  [[ "$git_dir" != "$git_common_dir" ]]
}

# ---------------------------------------------------------------------------
# get_project_name <dir>
#   Prints the main repo's directory name (even when called from a worktree).
#   Falls back to basename of dir if not in a git repo.
# ---------------------------------------------------------------------------
get_project_name() {
  local dir="$1"
  local common_dir
  common_dir=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null) || {
    basename "$dir"
    return
  }
  # Resolve to absolute, go up from .git dir to repo root
  basename "$(cd "$dir" && cd "$common_dir/.." && pwd)"
}

# ---------------------------------------------------------------------------
# play_notification <cwd> <branch> <is_worktree>
#   Plays the audio notification sequence and shows a macOS notification.
#   Format: project / [worktree /] branch
# ---------------------------------------------------------------------------
play_notification() {
  local cwd="$1"
  local branch="$2"
  local is_worktree="$3"
  local project worktree_name notification_text

  project=$(get_project_name "$cwd")

  afplay /System/Library/Sounds/Glass.aiff

  say "$project"

  if [[ "$is_worktree" == "true" ]]; then
    worktree_name=$(basename "$cwd")
    say "$worktree_name"
    sleep 0.3
    notification_text="$project / $worktree_name / $branch"
  else
    notification_text="$project / $branch"
  fi

  say "$branch"

  osascript -e "display notification \"$notification_text\" with title \"Claude Code\" subtitle \"Ready for input\""
}

# ---------------------------------------------------------------------------
# main — reads stdin, parses JSON, gathers git info, notifies.
# ---------------------------------------------------------------------------
main() {
  local input cwd branch is_worktree_flag

  input=$(cat /dev/stdin)

  cwd=$(parse_cwd_from_json "$input") || {
    echo "Error: could not parse cwd from hook JSON" >&2
    exit 1
  }

  branch=$(get_git_branch "$cwd")

  if is_git_worktree "$cwd"; then
    is_worktree_flag="true"
  else
    is_worktree_flag="false"
  fi

  play_notification "$cwd" "$branch" "$is_worktree_flag"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
