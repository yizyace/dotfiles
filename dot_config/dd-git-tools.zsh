# Remove oh-my-zsh git plugin's gg alias so we can define our function
unalias gg 2>/dev/null

gg() {
  local cmd="$1"
  shift 2>/dev/null

  # Aliases (expand before processing)
  case "$cmd" in
    co) cmd="checkout" ;;                     # checkout
    cob) cmd="checkout"; set -- -b "$@" ;;    # create and switch to new branch
    cm) cmd="commit" ;;                       # commit staged changes
  esac

  # Custom commands
  case "$cmd" in
    --help|-h|help)
      cat <<'HELP'
gg - git wrapper with shortcuts

ALIASES (expand to git commands):
  co        checkout
  cob       checkout -b (create and switch to new branch)
  cm        commit
  st        status
  br        branch -a (list all branches)
  dt        difftool
  tack      commit -a --amend (amend with all changes)
  lg        log with graph and pretty format
  lgo       log --oneline

CUSTOM COMMANDS:
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
    recent)
      local n="${1:-10}"
      git reflog show --pretty=format:'%gs' | grep 'checkout: moving' | sed 's/checkout: moving from .* to //' | awk '!seen[$0]++' | head -n "$n"
      return
      ;;
  esac

  # Default: delegate to git
  git "$cmd" "$@"
}
