# Remove oh-my-zsh git plugin's gg alias so we can define our function
unalias gg 2>/dev/null

# Command definitions - single source of truth for help and completion
typeset -a GG_ALIASES=(
  'cob:checkout -b (create branch)'
  'cm:commit'
  'st:status'
  'br:branch -a'
  'dt:difftool'
  'tack:commit -a --amend'
  'lg:log with graph'
  'lgo:log --oneline'
)

typeset -a GG_CUSTOM_COMMANDS=(
  'co:checkout with auto-cd to worktree'
  'recent:show recent branches'
  'conflicts:list conflict files'
  'g:grep with formatting'
  'search:case-insensitive grep'
  'logsearch:search commit messages'
  'ec:edit local config'
  'egc:edit global config'
  'ac:add all and commit'
  'checkpoint:create WIP checkpoint'
  'qq:interactive file picker'
  'forcepull:fetch and hard reset to upstream'
)

gg() {
  local cmd="$1"
  shift 2>/dev/null

  # Aliases (expand before processing)
  case "$cmd" in
    cob) cmd="checkout"; set -- -b "$@" ;;    # create and switch to new branch
    cm) cmd="commit" ;;                       # commit staged changes
    st) cmd="status" ;;                       # show working tree status
    br) cmd="branch"; set -- -a "$@" ;;       # list all branches
    dt) cmd="difftool" ;;                     # open diff in external tool
    tack) cmd="commit"; set -- -a --amend "$@" ;;  # amend with all changes
    lg) cmd="log"; set -- --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit "$@" ;;  # pretty log with graph
    lgo) cmd="log"; set -- --oneline "$@" ;;  # compact one-line log
  esac

  # Custom commands
  case "$cmd" in
    --help|-h|help)
      echo "gg - git wrapper with shortcuts"
      echo ""
      echo "ALIASES (expand to git commands):"
      for spec in "${GG_ALIASES[@]}"; do
        printf "  %-10s%s\n" "${spec%%:*}" "${spec#*:}"
      done
      echo ""
      echo "CUSTOM COMMANDS:"
      for spec in "${GG_CUSTOM_COMMANDS[@]}"; do
        printf "  %-14s%s\n" "${spec%%:*}" "${spec#*:}"
      done
      echo ""
      echo "All other commands are passed to git."
      return
      ;;
    co)
      local output
      output=$(git checkout "$@" 2>&1)
      local rc=$?
      # Handle both old ("already checked out at") and new ("already used by worktree at") git messages
      if [[ $rc -ne 0 && ("$output" == *"already checked out at '"* || "$output" == *"already used by worktree at '"*) ]]; then
        local wt_path
        if [[ "$output" == *"already checked out at '"* ]]; then
          wt_path=${output##*already checked out at \'}
        else
          wt_path=${output##*already used by worktree at \'}
        fi
        wt_path=${wt_path%\'}
        echo "Branch is in worktree: $wt_path"
        cd "$wt_path"
        return
      else
        [[ -n "$output" ]] && echo "$output"
        return $rc
      fi
      ;;
    recent)
      local interactive=0
      local n=10

      # Parse arguments
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -i|--interactive) interactive=1; shift ;;
          *) n="$1"; shift ;;
        esac
      done

      # Get the list of recent branches
      local branches
      branches=$(git reflog show --pretty=format:'%gs' | grep 'checkout: moving' | sed 's/checkout: moving from .* to //' | awk '!seen[$0]++' | head -n "$n")

      if [[ $interactive -eq 0 ]]; then
        echo "$branches"
        return
      fi

      # Interactive mode
      if ! command -v fzf >/dev/null 2>&1; then
        echo "Error: fzf is required for interactive mode but is not installed." >&2
        echo "Install with: brew install fzf" >&2
        echo "" >&2
        echo "Falling back to list mode:" >&2
        echo "$branches"
        return 1
      fi

      local selected
      selected=$(echo "$branches" | fzf --height=40% --reverse --border \
        --header="Select branch (Enter=checkout, Esc=cancel)" \
        --bind="j:down,k:up")

      if [[ -n "$selected" ]]; then
        gg co "$selected"
      fi
      return
      ;;
    conflicts)
      git diff --name-only --diff-filter=U
      return
      ;;
    g)
      git grep --break --heading -n "$@"
      return
      ;;
    search)
      git grep -Ii "$@"
      return
      ;;
    logsearch)
      git log --grep="$1" --oneline "${@:2}"
      return
      ;;
    ec)
      git config -e
      return
      ;;
    egc)
      git config --global -e
      return
      ;;
    ac)
      git add -A && git commit -m "$*"
      return
      ;;
    checkpoint)
      # Verify we're on a branch
      local current_branch
      current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
      if [[ -z "$current_branch" ]]; then
        echo "Error: Cannot checkpoint from detached HEAD state" >&2
        return 1
      fi

      # Check for changes (staged, unstaged, or untracked)
      local has_changes=false
      if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
        has_changes=true
      fi

      # Create WIP commit if there are changes
      if [[ "$has_changes" = true ]]; then
        git add -A && git commit -m "WIP"
      fi

      # Generate checkpoint branch name
      local date_prefix
      date_prefix=$(date +%y%m%d)

      # Extract base branch (handle checkpointing from a checkpoint branch)
      local base_branch="$current_branch"
      if [[ "$current_branch" == checkpoints/* ]]; then
        # Extract date and original branch from: checkpoints/YYMMDD/original-branch/N
        date_prefix=$(echo "$current_branch" | cut -d'/' -f2)
        base_branch=$(echo "$current_branch" | cut -d'/' -f3- | sed 's:/[0-9]*$::')
      fi

      # Find next checkpoint number (max existing + 1, not count + 1)
      local max_num=0
      local branches
      branches=$(git branch --list "checkpoints/${date_prefix}/${base_branch}/*")
      if [[ -n "$branches" ]]; then
        max_num=$(echo "$branches" | sed 's:.*/::' | sort -n | tail -1)
      fi
      local next_num=$((max_num + 1))

      local checkpoint_branch="checkpoints/${date_prefix}/${base_branch}/${next_num}"

      git branch "$checkpoint_branch"
      if [[ "$has_changes" = true ]]; then
        echo "Created checkpoint: $checkpoint_branch (with WIP commit)"
      else
        echo "Created checkpoint: $checkpoint_branch (no changes)"
      fi
      return
      ;;
    qq)
      git status | fpp -nfc
      return
      ;;
    forcepull)
      local current_branch
      current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
      if [[ -z "$current_branch" ]]; then
        echo "Error: Cannot forcepull in detached HEAD state" >&2
        return 1
      fi

      local upstream
      upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
      if [[ -z "$upstream" ]]; then
        echo "Error: No upstream tracking branch configured for '$current_branch'" >&2
        echo "Hint: run 'git branch --set-upstream-to=origin/$current_branch'" >&2
        return 1
      fi

      local remote="${upstream%%/*}"

      echo "Fetching from $remote..."
      if ! git fetch "$remote" "$current_branch"; then
        echo "Error: fetch from '$remote' failed" >&2
        return 1
      fi

      # Save uncommitted changes to reflog via WIP commit
      if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
        echo "Saving uncommitted changes as WIP commit..."
        git add -A
        git commit -qm "WIP (forcepull)"
      fi

      echo "Resetting '$current_branch' to '$upstream'..."
      git reset --hard "$upstream"
      return
      ;;
  esac

  # Default: delegate to git
  git "$cmd" "$@"
}

# Zsh completion for gg (only load in zsh)
if [[ -n "$ZSH_VERSION" ]]; then
  _gg() {
    # Build completion array from shared metadata
    local -a gg_commands=("${GG_ALIASES[@]}" "${GG_CUSTOM_COMMANDS[@]}")

    if (( CURRENT == 2 )); then
      # First argument: complete gg commands + git commands
      _describe 'gg command' gg_commands

      # Delegate to git completion with fully rewritten context
      # Must change words, service, AND curcontext to prevent recursion
      words[1]=git
      service=git
      curcontext="${curcontext/gg/git}"
      _git
    else
      # Subsequent arguments: use git completion
      words[1]=git
      service=git
      curcontext="${curcontext/gg/git}"
      _git
    fi
  }
  compdef _gg gg 2>/dev/null
fi
