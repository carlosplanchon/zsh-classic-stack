# ============================================================
#  ~/.zshrc - the zsh-classic-stack "classic" profile
#  https://github.com/carlosplanchon/zsh-classic-stack
# ============================================================
# A complete, framework-free zsh setup: sane options, shared history,
# proper keybindings, curated OMZ-style aliases, and the classic stack
# (fzf, zoxide, autosuggestions, syntax highlighting, completions) wired
# at the end in the correct order.
#
# Machine-specific config (PATH additions, EDITOR, private aliases) belongs
# in ~/.zshrc.local, which loads before the tool integrations so its PATH
# and env vars are visible to direnv, starship and the stack. Installed by
# install.sh, which backs up your previous ~/.zshrc first.

# --- PATH & environment -------------------------------------------
# -U on both: the flag on the array alone doesn't dedupe assignments via the scalar PATH.
typeset -U path PATH
export PATH="$HOME/.local/bin:$PATH"
[[ -n ${TTY:-} ]] && export GPG_TTY=$TTY

# GNU colors for ls, grep, and the completion menu.
if (( $+commands[dircolors] )); then
  eval "$(dircolors -b)"
fi

if (( $+commands[less] )); then
  export PAGER="${PAGER:-less}"
  export LESS="${LESS:--R}"
fi

# --- General behavior ---------------------------------------------
setopt INTERACTIVE_COMMENTS
setopt MULTIOS LONG_LIST_JOBS

# Navigation: typing a directory cds into it and every visit lands on the stack.
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT PUSHD_MINUS

# --- History -------------------------------------------------------
HISTFILE="$HOME/.zsh_history"
# HISTSIZE > SAVEHIST so HIST_EXPIRE_DUPS_FIRST has room to expire.
HISTSIZE=55000
SAVEHIST=50000

setopt EXTENDED_HISTORY SHARE_HISTORY HIST_EXPIRE_DUPS_FIRST \
       HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS \
       HIST_VERIFY HIST_FIND_NO_DUPS

# --- Completion ----------------------------------------------------
ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
mkdir -p -- "$ZSH_CACHE_DIR/completion"

zmodload -i zsh/complist
autoload -Uz compinit
compinit -d "$ZSH_CACHE_DIR/zcompdump"

# Compatibility with tools that only ship Bash completions.
autoload -Uz bashcompinit
bashcompinit

# Punctuation separates words when navigating with Ctrl+arrows.
WORDCHARS=''

unsetopt MENU_COMPLETE FLOW_CONTROL
setopt AUTO_MENU COMPLETE_IN_WORD ALWAYS_TO_END

zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*' matcher-list \
  'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' \
  'r:|=*' \
  'l:|=* r:|=*'
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' use-cache yes
zstyle ':completion:*' cache-path "$ZSH_CACHE_DIR/completion"

[[ -n "${LS_COLORS:-}" ]] && \
  zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# --- Line editor & keybindings ------------------------------------
bindkey -e
zmodload -i zsh/terminfo

# Up/down arrows: search history using the typed prefix.
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
[[ -n "${terminfo[kcuu1]}" ]] && bindkey "${terminfo[kcuu1]}" up-line-or-beginning-search
[[ -n "${terminfo[kcud1]}" ]] && bindkey "${terminfo[kcud1]}" down-line-or-beginning-search

# Ctrl+left/right: move by one word.
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word
bindkey '^[[5D' backward-word
bindkey '^[[5C' forward-word

# Alt+left/right: variant used by some terminals.
bindkey '^[[1;3D' backward-word
bindkey '^[[1;3C' forward-word

# Home, End, Delete, and Ctrl+Delete.
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[1~' beginning-of-line
bindkey '^[[4~' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[3;5~' kill-word

[[ -n "${terminfo[khome]}" ]] && bindkey "${terminfo[khome]}" beginning-of-line
[[ -n "${terminfo[kend]}" ]] && bindkey "${terminfo[kend]}" end-of-line
[[ -n "${terminfo[kdch1]}" ]] && bindkey "${terminfo[kdch1]}" delete-char

# Shift+Tab steps back in the completion menu.
bindkey '^[[Z' reverse-menu-complete
[[ -n "${terminfo[kcbt]}" ]] && bindkey "${terminfo[kcbt]}" reverse-menu-complete

# Ctrl+R searches history (fzf takes this over when installed);
# Ctrl+X Ctrl+E opens the line in $EDITOR.
bindkey '^R' history-incremental-search-backward
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '\C-x\C-e' edit-command-line

# Keeps history expansion visible before running it.
bindkey ' ' magic-space

# Smart paste: protects URLs with ?, &, #, etc.
autoload -Uz bracketed-paste-magic url-quote-magic
zle -N bracketed-paste bracketed-paste-magic
zle -N self-insert url-quote-magic

# --- Directory navigation -----------------------------------------
alias -- -='cd -'
alias 1='cd -1'
alias 2='cd -2'
alias 3='cd -3'
alias 4='cd -4'
alias 5='cd -5'
alias 6='cd -6'
alias 7='cd -7'
alias 8='cd -8'
alias 9='cd -9'

alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'
alias -g ......='../../../../..'

d() {
  if (( $# )); then
    dirs "$@"
  else
    dirs -v | head -n 10
  fi
}

compdef _dirs d 2>/dev/null

mkcd() {
  (( $# )) || {
    print -u2 'usage: mkcd DIRECTORY'
    return 1
  }

  mkdir -p -- "$@" && cd -- "${@[-1]}"
}

alias md='mkdir -p'
alias rd='rmdir'

# --- Git aliases ----------------------------------------------------
# A curated subset compatible with oh-my-zsh's git plugin muscle memory.
alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gst='git status'
alias gss='git status --short'
alias gc='git commit --verbose'
alias gca='git commit --verbose --all'
alias gcam='git commit --all --message'
alias gcmsg='git commit --message'
alias 'gc!'='git commit --verbose --amend'
alias 'gcan!'='git commit --verbose --all --no-edit --amend'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gb='git branch'
alias gba='git branch --all'
alias gd='git diff'
alias gdca='git diff --cached'
alias gds='git diff --staged'
alias gf='git fetch'
alias gfa='git fetch --all --tags --prune'
alias gl='git pull'
alias gpr='git pull --rebase'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias glo='git log --oneline --decorate'
alias glog='git log --oneline --decorate --graph'
alias gloga='git log --oneline --decorate --graph --all'
alias gm='git merge'
alias gma='git merge --abort'
alias gmc='git merge --continue'
alias gsta='git stash push'
alias gstp='git stash pop'
alias gstl='git stash list'

# --- General aliases ----------------------------------------------
if [[ $OSTYPE == darwin* ]]; then
  export CLICOLOR=1
  alias ls='ls -G'
else
  alias ls='ls --color=auto'
fi
alias grep='grep --color=auto'
alias l='ls -lah'
alias la='ls -lAh'
alias ll='ls -lh'
alias lsa='ls -lah'

# --- Clipboard -----------------------------------------------------
# clipcopy accepts stdin or a file; clippaste writes the current contents.
if (( $+commands[pbcopy] && $+commands[pbpaste] )); then
  clipcopy() {
    if (( $# )); then
      pbcopy < "$1"
    else
      pbcopy
    fi
  }
  clippaste() { pbpaste }
elif (( $+commands[wl-copy] && $+commands[wl-paste] )); then
  clipcopy() {
    if (( $# )); then
      wl-copy < "$1"
    else
      wl-copy
    fi
  }
  clippaste() { wl-paste --no-newline }
elif (( $+commands[xclip] )); then
  clipcopy() {
    if (( $# )); then
      xclip -selection clipboard -in < "$1"
    else
      xclip -selection clipboard -in
    fi
  }
  clippaste() { xclip -selection clipboard -out }
fi

# --- Dynamic terminal title ---------------------------------------
autoload -Uz add-zsh-hook

_terminal_title_precmd() {
  print -Pn '\e]0;%n@%m: %~\a'
}

_terminal_title_preexec() {
  # Without -r the command could inject escapes into the terminal; non-printables are filtered out.
  print -rn -- $'\e]0;'"${1//[^[:print:]]/}"$'\a'
}

add-zsh-hook precmd _terminal_title_precmd
add-zsh-hook preexec _terminal_title_preexec

# --- Personal machine-specific config ------------------------------
# Before the integrations below on purpose: PATH additions made here can
# make direnv or starship visible, and env vars (STARSHIP_CONFIG, _ZO_*)
# exist before the tools initialize. Aliases defined here override the
# general ones above.
[[ -r "${ZDOTDIR:-$HOME}/.zshrc.local" ]] && source "${ZDOTDIR:-$HOME}/.zshrc.local"

# --- Integrations --------------------------------------------------
(( $+commands[direnv] )) && eval "$(direnv hook zsh)"

# --- Prompt: Starship ----------------------------------------------
# For a Powerlevel10k rainbow look, pair this profile with
# https://github.com/carlosplanchon/starship-p10k-rainbow
(( $+commands[starship] )) && eval "$(starship init zsh)"

# --- The classic stack (keep last: syntax highlighting must load last)
[[ -r "$HOME/.zsh/classic-stack.zsh" ]] && source "$HOME/.zsh/classic-stack.zsh"
