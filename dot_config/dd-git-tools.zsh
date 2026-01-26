# Remove oh-my-zsh git plugin's gg alias so we can define our function
unalias gg 2>/dev/null

gg() {
  local cmd="$1"
  shift 2>/dev/null

  # Aliases (expand before processing)
  case "$cmd" in
    co) cmd="checkout" ;;
  esac

  # Custom commands
  case "$cmd" in
    recent)
      local n="${1:-10}"
      git reflog show --pretty=format:'%gs' | grep 'checkout: moving' | sed 's/checkout: moving from .* to //' | awk '!seen[$0]++' | head -n "$n"
      return
      ;;
  esac

  # Default: delegate to git
  git "$cmd" "$@"
}
