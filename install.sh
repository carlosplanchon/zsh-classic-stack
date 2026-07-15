#!/bin/sh
# Full migration: replaces ~/.zshrc with the classic profile
# (profiles/classic.zshrc) after a timestamped backup, then wires the stack
# via check.sh --enable. Nothing is ever deleted: an existing oh-my-zsh or
# Powerlevel10k install stays on disk, it just stops being loaded, so
# reverting is restoring the backup. Machine-specific config (PATH, EDITOR,
# private aliases) goes in ~/.zshrc.local, which the profile loads.
#
# Safe by default: with no arguments it only prints the plan.
#   curl -sS https://raw.githubusercontent.com/carlosplanchon/zsh-classic-stack/main/install.sh | sh
#   curl -sS https://raw.githubusercontent.com/carlosplanchon/zsh-classic-stack/main/install.sh | sh -s -- --yes
set -eu

RAW_BASE='https://raw.githubusercontent.com/carlosplanchon/zsh-classic-stack/main'
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"

say() { printf '%s\n' "$*"; }

YES=0
for arg in "$@"; do
  case "$arg" in
    --yes) YES=1 ;;
    -h|--help)
      say 'usage: install.sh [--yes]'
      say ''
      say 'Replaces ~/.zshrc with the classic profile (backup first) and wires'
      say 'the stack via check.sh --enable. Never deletes anything: oh-my-zsh or'
      say 'Powerlevel10k files stay on disk, they just stop being loaded.'
      say ''
      say '  (no args)  print the plan and exit; nothing is touched'
      say '  --yes      apply it'
      exit 0 ;;
    *) say "unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

# Companion files: use the repo checkout when run from one, otherwise fetch.
tmp_profile=''; tmp_check=''
trap 'rm -f "$tmp_profile" "$tmp_check"' EXIT
selfdir=$(dirname "$0")
if [ -f "$selfdir/profiles/classic.zshrc" ] && [ -f "$selfdir/check.sh" ]; then
  PROFILE="$selfdir/profiles/classic.zshrc"
  CHECK="$selfdir/check.sh"
else
  if command -v curl >/dev/null 2>&1; then
    fetch() { curl -fsSL "$1" -o "$2"; }
  elif command -v wget >/dev/null 2>&1; then
    fetch() { wget -qO "$2" "$1"; }
  else
    say 'error: need curl or wget to download the profile.' >&2
    exit 1
  fi
  tmp_profile=$(mktemp); tmp_check=$(mktemp)
  fetch "$RAW_BASE/profiles/classic.zshrc" "$tmp_profile" || {
    say "error: could not download $RAW_BASE/profiles/classic.zshrc" >&2
    exit 1
  }
  fetch "$RAW_BASE/check.sh" "$tmp_check" || {
    say "error: could not download $RAW_BASE/check.sh" >&2
    exit 1
  }
  grep -q 'zsh-classic-stack "classic" profile' "$tmp_profile" || {
    say 'error: downloaded file does not look like the profile; aborting.' >&2
    exit 1
  }
  PROFILE="$tmp_profile"
  CHECK="$tmp_check"
fi

# ---------- the plan ----------

say 'plan:'
say "  1. replace $ZSHRC with the classic profile"
if [ -f "$ZSHRC" ]; then
  say "     (current file backed up first as $ZSHRC.bak.<timestamp>)"
  if grep -qsE 'oh-my-zsh\.sh|powerlevel10k/powerlevel10k|powerlevel10k\.zsh-theme|\.p10k\.zsh' "$ZSHRC"; then
    say '     note: your current config loads Oh My Zsh / Powerlevel10k. Those'
    say '     lines are not carried over, so they stop running; their files'
    say '     stay untouched on disk and the backup restores everything.'
  fi
else
  say '     (no existing file: nothing to back up)'
fi
say '  2. run check.sh --enable to (re)generate ~/.zsh/classic-stack.zsh'
say '     with the right paths for this system'
say '  3. nothing else: no sudo, no installs, no deletions'
say ''
say "  your own PATH, EDITOR and private aliases belong in ${ZDOTDIR:-$HOME}/.zshrc.local,"
say '  which the profile loads automatically. Salvage them from the backup.'
say ''

if [ "$YES" -ne 1 ]; then
  say 'nothing done. rerun with --yes to apply:'
  say "  curl -sS $RAW_BASE/install.sh | sh -s -- --yes"
  exit 0
fi

# ---------- apply ----------

if [ -f "$ZSHRC" ]; then
  bak="$ZSHRC.bak.$(date +%Y%m%d-%H%M%S)"
  cp "$ZSHRC" "$bak"
  say "backed up $ZSHRC to $bak"
fi
mkdir -p "$(dirname "$ZSHRC")"
cp "$PROFILE" "$ZSHRC"
chmod 644 "$ZSHRC"
say "classic profile installed at $ZSHRC"
say ''
say "machine-specific config goes in ${ZDOTDIR:-$HOME}/.zshrc.local; for instance:"
say '  export EDITOR=nvim'
# shellcheck disable=SC2016  # printed literally: the line belongs in ~/.zshrc.local.
say '  export PATH="$HOME/.cargo/bin:$PATH"'
say "  alias work='cd ~/work'"
say 'a fuller commented example ships with the repo:'
say '  https://github.com/carlosplanchon/zsh-classic-stack/blob/main/examples/zshrc.local'
say ''

sh "$CHECK" --enable

if ! command -v zsh >/dev/null 2>&1; then
  say ''
  say 'note: zsh itself is missing, so the stack file was NOT created yet.'
  say 'after installing the packages above, finish the wiring with:'
  say "  curl -sS $RAW_BASE/check.sh | sh -s -- --enable"
fi

if ! command -v starship >/dev/null 2>&1; then
  say ''
  say 'note: starship is not installed, so the prompt stays plain for now.'
  say 'for the prompt (and a p10k rainbow look) see:'
  say '  https://github.com/carlosplanchon/starship-p10k-rainbow'
fi
