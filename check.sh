#!/bin/sh
# Reports the state of the classic zsh interactive stack on this machine:
# zsh itself, fzf, zoxide, zsh-autosuggestions, zsh-syntax-highlighting and
# zsh-completions. For anything missing or not enabled it prints the exact
# package-manager command and ~/.zshrc line for your system.
#
# By default it only reads: it never runs sudo, never installs, never edits.
# With --enable it wires up what is installed, through exactly one file it
# owns (~/.zsh/classic-stack.zsh, regenerated on every run) plus one source
# line in ~/.zshrc (added once, after a timestamped backup). It still never
# installs anything.
#
# Pipe it:
#   curl -sS https://raw.githubusercontent.com/carlosplanchon/zsh-classic-stack/main/check.sh | sh
#   curl -sS https://raw.githubusercontent.com/carlosplanchon/zsh-classic-stack/main/check.sh | sh -s -- --enable
set -eu

say() { printf '%s\n' "$*"; }

ENABLE=0
for arg in "$@"; do
  case "$arg" in
    --enable) ENABLE=1 ;;
    -h|--help)
      say 'usage: check.sh [--enable]'
      say ''
      say 'Reports zsh, fzf, zoxide, zsh-autosuggestions, zsh-syntax-highlighting'
      say 'and zsh-completions: what is installed, what is enabled in ~/.zshrc,'
      say 'and the exact install command for your system for whatever is missing.'
      say 'It never installs anything on its own.'
      say ''
      say '  --enable  wire up the stack: write ~/.zsh/classic-stack.zsh (owned by'
      say '            this script, safe to regenerate) and add one source line to'
      say '            ~/.zshrc, backing it up first. Tools stay uninstalled until'
      say '            you install them; the file picks each one up automatically.'
      say ''
      say 'For a full migration (replace ~/.zshrc with the classic profile, e.g.'
      say 'coming from oh-my-zsh / Powerlevel10k) use install.sh from this repo.'
      exit 0 ;;
    *) say "unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

# Detected once and used only to print accurate instructions, never to install.
if   command -v pacman  >/dev/null 2>&1; then PM=pacman
elif command -v apt-get >/dev/null 2>&1; then PM=apt
elif command -v dnf     >/dev/null 2>&1; then PM=dnf
elif command -v brew    >/dev/null 2>&1; then PM=brew
else PM=unknown
fi

ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
SNIPPET="$HOME/.zsh/classic-stack.zsh"
if command -v zsh >/dev/null 2>&1; then HAVE_ZSH=1; else HAVE_ZSH=0; fi

# Missing packages pile up here; the report ends with one combined install
# command so a fresh machine is a single paste away.
MISSING=''

# Cheap "already wired up" heuristic: the name appears in ~/.zshrc. Also
# catches plugin-manager setups (oh-my-zsh, zinit, ...) that keep plugins
# outside the package paths probed below.
in_zshrc() { grep -qs -- "$1" "$ZSHRC"; }

BREW_SHARE=''
if [ "$PM" = brew ]; then
  if BREW_SHARE=$(brew --prefix 2>/dev/null); then
    BREW_SHARE="$BREW_SHARE/share"
  else
    BREW_SHARE=''
  fi
fi

# Verified package names and paths, per supported system:
#   Arch:          all five packaged; plugins in /usr/share/zsh/plugins/<name>/
#   Debian/Ubuntu: no zsh-completions package; plugins in /usr/share/<name>/
#   Fedora:        no zsh-completions package; plugins in /usr/share/<name>/
#   Homebrew:      all five packaged; plugins in $(brew --prefix)/share/<name>/
case $PM in
  pacman)
    as_cmd='sudo pacman -S zsh-autosuggestions'
    as_path='/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh'
    hl_cmd='sudo pacman -S zsh-syntax-highlighting'
    hl_path='/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh'
    comp_dir='' ;;  # pacman's zsh-completions lands in fpath by itself
  apt)
    as_cmd='sudo apt install zsh-autosuggestions'
    as_path='/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh'
    hl_cmd='sudo apt install zsh-syntax-highlighting'
    hl_path='/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh'
    comp_dir="$HOME/.zsh/zsh-completions/src" ;;
  dnf)
    as_cmd='sudo dnf install zsh-autosuggestions'
    as_path='/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh'
    hl_cmd='sudo dnf install zsh-syntax-highlighting'
    hl_path='/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh'
    comp_dir="$HOME/.zsh/zsh-completions/src" ;;
  brew)
    as_cmd='brew install zsh-autosuggestions'
    as_path="$BREW_SHARE/zsh-autosuggestions/zsh-autosuggestions.zsh"
    hl_cmd='brew install zsh-syntax-highlighting'
    hl_path="$BREW_SHARE/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    comp_dir="$BREW_SHARE/zsh-completions" ;;
  *)
    as_cmd='https://github.com/zsh-users/zsh-autosuggestions/blob/master/INSTALL.md'
    as_path=''
    hl_cmd='https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/INSTALL.md'
    hl_path=''
    comp_dir='' ;;
esac

# Prints where a plugin's main file actually is, probing the path every
# supported package manager uses.
plugin_path() {
  if [ -f "/usr/share/zsh/plugins/$1/$1.zsh" ]; then
    printf '%s\n' "/usr/share/zsh/plugins/$1/$1.zsh"
  elif [ -f "/usr/share/$1/$1.zsh" ]; then
    printf '%s\n' "/usr/share/$1/$1.zsh"
  elif [ -n "$BREW_SHARE" ] && [ -f "$BREW_SHARE/$1/$1.zsh" ]; then
    printf '%s\n' "$BREW_SHARE/$1/$1.zsh"
  else
    return 1
  fi
}

# ---------- the managed snippet (--enable) ----------

# The whole point of the snippet: the ordering rules (completions fpath
# before compinit, zoxide after compinit, syntax-highlighting last) hold by
# construction inside one file, instead of being guessed against an
# arbitrary ~/.zshrc. Every block guards on its tool being present, so the
# file adapts as tools are installed or removed, without regeneration.
write_snippet() {
  if ! s_as=$(plugin_path zsh-autosuggestions); then s_as="$as_path"; fi
  if ! s_hl=$(plugin_path zsh-syntax-highlighting); then s_hl="$hl_path"; fi
  {
    say '# Generated by zsh-classic-stack (check.sh --enable). Do not edit: this'
    say '# file is overwritten on every --enable run; personal config belongs in'
    say '# ~/.zshrc. Every block no-ops until its tool is installed, so it adapts'
    say '# as tools come and go. Keep its source line near the end of ~/.zshrc so'
    say '# zsh-syntax-highlighting stays the last plugin loaded.'
    say ''
    if [ -n "$comp_dir" ]; then
      say '# zsh-completions: its directory must be in fpath before compinit runs.'
      say "if [[ -d $comp_dir ]]; then"
      say "  fpath=($comp_dir \$fpath)"
      say 'fi'
      say ''
      say '# Completion system: initialize once; if an earlier compinit already ran'
      say '# in ~/.zshrc, run it again so the directory above gets scanned too.'
      say 'if ! whence compdef >/dev/null; then'
      say '  autoload -Uz compinit'
      say '  compinit'
      say "elif [[ -d $comp_dir ]]; then"
      say '  compinit'
      say 'fi'
    else
      say '# Completion system: initialize once (fzf and zoxide completions use it).'
      say 'if ! whence compdef >/dev/null; then'
      say '  autoload -Uz compinit'
      say '  compinit'
      say 'fi'
    fi
    say ''
    say '# fzf: Ctrl-R history search and fuzzy completion. The extra probe skips'
    say '# builds too old for --zsh instead of erroring on every shell start.'
    say 'if command -v fzf >/dev/null && fzf --zsh >/dev/null 2>&1; then'
    say '  source <(fzf --zsh)'
    say 'fi'
    if [ -n "$s_as" ]; then
      say ''
      say '# zsh-autosuggestions: fish-style history suggestions.'
      say "if [[ -r $s_as ]] && ! whence _zsh_autosuggest_start >/dev/null; then"
      say "  source $s_as"
      say 'fi'
    fi
    say ''
    say '# zoxide: smarter cd. Must come after compinit.'
    say 'if command -v zoxide >/dev/null && ! whence __zoxide_z >/dev/null; then'
    # shellcheck disable=SC2016  # written literally into the zsh snippet.
    say '  eval "$(zoxide init zsh)"'
    say 'fi'
    if [ -n "$s_hl" ]; then
      say ''
      say '# zsh-syntax-highlighting: keep this the last plugin loaded.'
      say "if [[ -r $s_hl ]] && ! whence _zsh_highlight >/dev/null; then"
      say "  source $s_hl"
      say 'fi'
    fi
  } > "$SNIPPET"
}

apply_enable() {
  say 'enable:'
  if [ "$HAVE_ZSH" -eq 0 ]; then
    say '  [??] zsh itself is not installed; nothing to wire up yet. Install zsh'
    say '       (see the report below) and rerun with --enable.'
    say ''
    return 0
  fi
  mkdir -p "$HOME/.zsh"
  write_snippet
  say "  [ok] wrote $SNIPPET"
  if grep -qs 'classic-stack.zsh' "$ZSHRC"; then
    say "  [ok] $ZSHRC already sources it; nothing else to do"
  else
    if [ -f "$ZSHRC" ]; then
      zbak="$ZSHRC.bak.$(date +%Y%m%d-%H%M%S)"
      cp "$ZSHRC" "$zbak"
      say "  [ok] backed up $ZSHRC to $zbak"
    fi
    {
      printf '\n%s\n' '# the classic zsh stack; added by zsh-classic-stack (check.sh --enable)'
      printf '%s\n' 'source ~/.zsh/classic-stack.zsh'
    } >> "$ZSHRC"
    say "  [ok] added the source line at the end of $ZSHRC"
  fi
  say ''
}

if [ "$ENABLE" -eq 1 ]; then apply_enable; fi

# Wired through the managed snippet: ~/.zshrc sources it and it exists. Then
# every tool below loads automatically as soon as it is installed.
if grep -qs 'classic-stack.zsh' "$ZSHRC" && [ -f "$SNIPPET" ]; then
  STACK_WIRED=1
else
  STACK_WIRED=0
fi

# ---------- the report ----------

# $1 name, $2 description, $3 install command, $4 file to source after that
# install ('' when not packaged for this system), $5 extra caveat line or ''.
plugin_report() {
  p_name=$1; p_desc=$2; p_cmd=$3; p_expect=$4; p_note=$5
  if p_have=$(plugin_path "$p_name"); then
    if [ "$STACK_WIRED" -eq 1 ] || in_zshrc "$p_name"; then
      say "  [ok] $p_name"
    else
      say "  [ok] $p_name: installed but not enabled; add to ~/.zshrc:"
      say "         source $p_have"
      if [ -n "$p_note" ]; then say "$p_note"; fi
    fi
  elif in_zshrc "$p_name"; then
    say "  [ok] $p_name (managed from ~/.zshrc)"
  else
    say "  [--] $p_name: $p_desc Install it:"
    say "         $p_cmd"
    if [ -n "$p_expect" ]; then MISSING="$MISSING $p_name"; fi
    if [ "$STACK_WIRED" -eq 1 ]; then
      say '       (already wired: the stack file loads it as soon as it lands)'
    elif [ -n "$p_expect" ]; then
      say "       then add to ~/.zshrc:"
      say "         source $p_expect"
      if [ -n "$p_note" ]; then say "$p_note"; fi
    fi
  fi
}

say 'the classic zsh stack:'

if [ "$HAVE_ZSH" -eq 1 ]; then
  say '  [ok] zsh'
else
  say '  [--] zsh: the shell all of this runs in. Install it:'
  case $PM in
    pacman) say '         sudo pacman -S zsh' ;;
    apt)    say '         sudo apt install zsh' ;;
    dnf)    say '         sudo dnf install zsh' ;;
    brew)   say '         brew install zsh' ;;
    *)      say '         use your system package manager' ;;
  esac
  # shellcheck disable=SC2016  # printed literally: a command for the user to type.
  say '       then make it your login shell:  chsh -s "$(command -v zsh)"'
  MISSING="$MISSING zsh"
fi

# A config still driven by oh-my-zsh / Powerlevel10k wins over anything
# --enable appends; flag it instead of silently coexisting with it.
if grep -qsE 'oh-my-zsh\.sh|powerlevel10k/powerlevel10k|powerlevel10k\.zsh-theme|\.p10k\.zsh' "$ZSHRC"; then
  say '  [!!] your ~/.zshrc still loads Oh My Zsh / Powerlevel10k. --enable only'
  say '       adds to your config, never removes: the old setup stays in charge.'
  say '       For a full migration to the classic profile (backup included):'
  say '         curl -sS https://raw.githubusercontent.com/carlosplanchon/zsh-classic-stack/main/install.sh | sh'
fi

if command -v starship >/dev/null 2>&1; then
  if [ "$HAVE_ZSH" -eq 1 ] && ! in_zshrc starship; then
    say '  [ok] starship: installed but not seen in ~/.zshrc; enable it by adding,'
    # shellcheck disable=SC2016  # printed literally: the line belongs in ~/.zshrc.
    say '       before the stack line:  eval "$(starship init zsh)"'
  else
    say '  [ok] starship'
  fi
else
  say '  [--] starship: the prompt engine (for a p10k rainbow look, pair it with'
  say '       https://github.com/carlosplanchon/starship-p10k-rainbow). Install it:'
  case $PM in
    pacman) say '         sudo pacman -S starship'
            MISSING="$MISSING starship" ;;
    dnf)    say '         sudo dnf install starship'
            MISSING="$MISSING starship" ;;
    brew)   say '         brew install starship'
            MISSING="$MISSING starship" ;;
    *)      say '         curl -sS https://starship.rs/install.sh | sh'
            if [ "$PM" = apt ]; then
              say '       (Debian and Ubuntu package it late and old, when at all;'
              say '        the official installer is current and works everywhere)'
            fi ;;
  esac
  if [ "$HAVE_ZSH" -eq 1 ]; then
    # shellcheck disable=SC2016  # printed literally: the line belongs in ~/.zshrc.
    say '       then add to ~/.zshrc:  eval "$(starship init zsh)"'
  fi
fi

if command -v fzf >/dev/null 2>&1; then
  if [ "$HAVE_ZSH" -eq 0 ] || in_zshrc fzf; then
    say '  [ok] fzf'
  elif [ "$STACK_WIRED" -eq 1 ]; then
    if fzf --zsh >/dev/null 2>&1 </dev/null; then
      say '  [ok] fzf'
    else
      say '  [ok] fzf (too old for --zsh, so the stack file skips it; see'
      say '       https://github.com/junegunn/fzf#setting-up-shell-integration)'
    fi
  else
    say '  [ok] fzf: installed but not seen in ~/.zshrc; for Ctrl-R history and'
    if fzf --zsh >/dev/null 2>&1 </dev/null; then
      say '       fuzzy completion, add there:  source <(fzf --zsh)'
    else
      say '       fuzzy completion, see:'
      say '         https://github.com/junegunn/fzf#setting-up-shell-integration'
    fi
  fi
else
  say '  [--] fzf: fuzzy finder (Ctrl-R history search, file picking). Install it:'
  case $PM in
    pacman) say '         sudo pacman -S fzf' ;;
    apt)    say '         sudo apt install fzf' ;;
    dnf)    say '         sudo dnf install fzf' ;;
    brew)   say '         brew install fzf' ;;
    *)      say '         https://github.com/junegunn/fzf#installation' ;;
  esac
  MISSING="$MISSING fzf"
  if [ "$STACK_WIRED" -eq 1 ]; then
    say '       (already wired: the stack file loads it as soon as it lands)'
  elif [ "$HAVE_ZSH" -eq 1 ]; then
    say '       then add to ~/.zshrc:  source <(fzf --zsh)'
    if [ "$PM" = apt ]; then
      say '       (distro builds can be too old for --zsh; then see'
      say '        https://github.com/junegunn/fzf#setting-up-shell-integration)'
    fi
  fi
fi

if command -v zoxide >/dev/null 2>&1; then
  if [ "$HAVE_ZSH" -eq 1 ] && [ "$STACK_WIRED" -eq 0 ] && ! in_zshrc zoxide; then
    say '  [ok] zoxide: installed but not seen in ~/.zshrc; enable it by adding,'
    # shellcheck disable=SC2016  # printed literally: the line belongs in ~/.zshrc.
    say '       at the very end (after compinit):  eval "$(zoxide init zsh)"'
  else
    say '  [ok] zoxide'
  fi
else
  say '  [--] zoxide: a smarter cd that remembers your directories. Install it:'
  case $PM in
    pacman) say '         sudo pacman -S zoxide' ;;
    dnf)    say '         sudo dnf install zoxide' ;;
    brew)   say '         brew install zoxide' ;;
    apt)    say '         sudo apt install zoxide'
            say '       (Debian and Ubuntu ship old versions; upstream recommends its script:'
            say '        curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh)' ;;
    *)      say '         curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh' ;;
  esac
  MISSING="$MISSING zoxide"
  if [ "$STACK_WIRED" -eq 1 ]; then
    say '       (already wired: the stack file loads it as soon as it lands)'
  elif [ "$HAVE_ZSH" -eq 1 ]; then
    # shellcheck disable=SC2016  # printed literally: the line belongs in ~/.zshrc.
    say '       then add at the very end of ~/.zshrc:  eval "$(zoxide init zsh)"'
  fi
fi

if [ "$HAVE_ZSH" -eq 1 ]; then
  plugin_report zsh-autosuggestions \
    'fish-style suggestions from your history as you type.' \
    "$as_cmd" "$as_path" ''
  plugin_report zsh-syntax-highlighting \
    'colors the command line as you type, errors in red.' \
    "$hl_cmd" "$hl_path" \
    '       (as the very last line: it must load after every other plugin)'

  if [ "$PM" = pacman ] && pacman -Qq zsh-completions >/dev/null 2>&1; then
    say '  [ok] zsh-completions (its functions sit in fpath; no zshrc line needed)'
  elif [ -n "$comp_dir" ] && [ -d "$comp_dir" ]; then
    if [ "$STACK_WIRED" -eq 1 ] || in_zshrc zsh-completions; then
      say '  [ok] zsh-completions'
    else
      say '  [ok] zsh-completions: installed but not enabled; add to ~/.zshrc,'
      if [ "$PM" = brew ]; then
        say "       before compinit:  FPATH=$comp_dir:\$FPATH"
      else
        # shellcheck disable=SC2016  # printed literally: the line belongs in ~/.zshrc.
        say "       before compinit:  fpath=($comp_dir \$fpath)"
      fi
    fi
  elif in_zshrc zsh-completions; then
    say '  [ok] zsh-completions (managed from ~/.zshrc)'
  else
    say '  [--] zsh-completions: extra tab-completion definitions. Install it:'
    case $PM in
      pacman)
        say '         sudo pacman -S zsh-completions'
        say '       (its functions land in fpath; no zshrc change needed)'
        MISSING="$MISSING zsh-completions" ;;
      brew)
        say '         brew install zsh-completions'
        if [ "$STACK_WIRED" -eq 1 ]; then
          say '       (already wired: the stack file adds it to fpath once it lands)'
        else
          say '       then add to ~/.zshrc, before compinit:'
          say "         FPATH=$comp_dir:\$FPATH"
        fi
        MISSING="$MISSING zsh-completions" ;;
      apt|dnf)
        say '         (not packaged on Debian, Ubuntu or Fedora; clone it instead)'
        say '         git clone https://github.com/zsh-users/zsh-completions ~/.zsh/zsh-completions'
        if [ "$STACK_WIRED" -eq 1 ]; then
          say '       (already wired: the stack file adds it to fpath once cloned)'
        else
          say '       then add to ~/.zshrc, before compinit:'
          # shellcheck disable=SC2016  # printed literally: the line belongs in ~/.zshrc.
          say '         fpath=(~/.zsh/zsh-completions/src $fpath)'
        fi ;;
      *)
        say '         https://github.com/zsh-users/zsh-completions#usage' ;;
    esac
  fi
else
  say '  [??] zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions:'
  say '       skipped until zsh is installed.'
  # Their files are detectable without zsh; probe them anyway so the
  # combined command below can cover a fresh machine in one go.
  if ! plugin_path zsh-autosuggestions >/dev/null; then
    MISSING="$MISSING zsh-autosuggestions"
  fi
  if ! plugin_path zsh-syntax-highlighting >/dev/null; then
    MISSING="$MISSING zsh-syntax-highlighting"
  fi
  if [ "$PM" = pacman ] && ! pacman -Qq zsh-completions >/dev/null 2>&1; then
    MISSING="$MISSING zsh-completions"
  elif [ "$PM" = brew ] && [ -n "$comp_dir" ] && [ ! -d "$comp_dir" ]; then
    MISSING="$MISSING zsh-completions"
  fi
fi

if [ -n "$MISSING" ] && [ "$PM" != unknown ]; then
  say ''
  # "available from" and not "everything": on apt and dnf some pieces
  # install by script or clone instead and stay out of this line.
  say "missing packages available from $PM, in one command:"
  case $PM in
    pacman) say "  sudo pacman -S --needed$MISSING" ;;
    apt)    say "  sudo apt install$MISSING" ;;
    dnf)    say "  sudo dnf install$MISSING" ;;
    brew)   say "  brew install$MISSING" ;;
  esac
fi

say ''
if [ "$ENABLE" -eq 1 ] || [ "$STACK_WIRED" -eq 1 ]; then
  say 'done. changes apply in new shells (or run: exec zsh).'
else
  say 'done. rerun with --enable to wire up the installed tools automatically.'
fi
