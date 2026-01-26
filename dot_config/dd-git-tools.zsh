# Remove oh-my-zsh git plugin's gg alias so we can define our function
unalias gg 2>/dev/null

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
      cat <<'HELP'
gg - git wrapper with shortcuts

ALIASES (expand to git commands):
  cob       checkout -b (create and switch to new branch)
  cm        commit
  st        status
  br        branch -a (list all branches)
  dt        difftool
  tack      commit -a --amend (amend with all changes)
  lg        log with graph and pretty format
  lgo       log --oneline

CUSTOM COMMANDS:
  co <branch>    checkout (auto-cd to worktree if branch checked out there)
  recent [n]     Show last n branches visited (default: 10)
  recent -i [n]  Interactive picker to checkout a recent branch (requires fzf)
  conflicts      List files with merge conflicts
  g <pattern>    Grep with nice formatting
  search <pat>   Case-insensitive grep
  logsearch <p>  Search commit messages
  ec             Edit local git config
  egc            Edit global git config
  ac <msg>       Stage all and commit with message
  checkpoint     Create WIP commit and switch to dated checkpoint branch
  qq             Interactive file picker for status

All other commands are passed to git.
HELP
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
      if git diff --quiet && git diff --cached --quiet && [[ -z "$(git ls-files --others --exclude-standard)" ]]; then
        echo "No changes to checkpoint" >&2
        return 1
      fi

      # Create WIP commit
      git add -A && git commit -m "WIP"

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

      git checkout -b "$checkpoint_branch"
      echo "Created checkpoint: $checkpoint_branch"
      return
      ;;
    qq)
      git status | fpp -nfc
      return
      ;;
  esac

  # Default: delegate to git
  git "$cmd" "$@"
}

# Zsh completion for gg (only load in zsh)
if [[ -n "$ZSH_VERSION" ]]; then
  _gg() {
    local -a gg_commands

    # Parse commands from help text (single source of truth)
    # Matches lines like "  cmd       description" or "  cmd <arg>  description"
    gg_commands=($(gg --help | awk '/^  [a-z]/ { print $1 }' | sort -u))

    if (( CURRENT == 2 )); then
      # First argument: complete gg commands + git commands
      _describe 'gg command' gg_commands
      _git  # Fall back to git completion
    else
      # Subsequent arguments: use git completion
      _git
    fi
  }
  compdef _gg gg
fi
