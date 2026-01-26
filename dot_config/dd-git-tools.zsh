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
  conflicts      List files with merge conflicts
  g <pattern>    Grep with nice formatting
  search <pat>   Case-insensitive grep
  logsearch <p>  Search commit messages
  ec             Edit local git config
  egc            Edit global git config
  ac <msg>       Stage all and commit with message
  wipe           Create savepoint, then reset hard
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
      local n="${1:-10}"
      git reflog show --pretty=format:'%gs' | grep 'checkout: moving' | sed 's/checkout: moving from .* to //' | awk '!seen[$0]++' | head -n "$n"
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
    wipe)
      git add -A && git commit -qm 'WIPE SAVEPOINT' && git reset HEAD~1 --hard
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
