# zsh-classic-stack

[![ci](https://github.com/carlosplanchon/zsh-classic-stack/actions/workflows/ci.yml/badge.svg)](https://github.com/carlosplanchon/zsh-classic-stack/actions/workflows/ci.yml)

One script that checks the classic zsh interactive stack on your machine:
[zsh](https://www.zsh.org/) itself,
[starship](https://starship.rs/) (the prompt engine),
[fzf](https://github.com/junegunn/fzf),
[zoxide](https://github.com/ajeetdsouza/zoxide),
[zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions),
[zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
and [zsh-completions](https://github.com/zsh-users/zsh-completions).
Report-only by default; the opt-in `--enable` wires up whatever is already
installed, and `install.sh` goes all the way: it replaces your `~/.zshrc`
with a complete, framework-free profile when you want a real migration off
oh-my-zsh / Powerlevel10k.

For each tool it reports one of three states:

- **installed and enabled**: nothing to do;
- **installed but not enabled**: prints the exact `~/.zshrc` line for your
  system (source paths differ per distro);
- **not installed**: prints the exact install command for your package
  manager.

When packaged dependencies are missing, the report ends with one combined
command for your package manager (with `--needed` on pacman). Pieces that
install by script or clone instead (starship on apt, zsh-completions on
apt and dnf) keep their own lines.

It reads your `~/.zshrc` to tell those states apart, but by default it never
edits anything, never installs anything, and never runs sudo. Run it as
often as you like:

```sh
curl -sS https://raw.githubusercontent.com/carlosplanchon/zsh-classic-stack/main/check.sh | sh
```

## Wiring it up: `--enable`

```sh
curl -sS https://raw.githubusercontent.com/carlosplanchon/zsh-classic-stack/main/check.sh | sh -s -- --enable
```

`--enable` makes exactly two writes, and installing tools is still on you:

1. It generates `~/.zsh/classic-stack.zsh`, a file this script owns and
   fully regenerates on every `--enable` run. Inside it the ordering rules
   hold by construction: the zsh-completions directory joins `fpath` before
   `compinit`, `compinit` runs once (or rescans if your `~/.zshrc` already
   ran it), fzf and zsh-autosuggestions load next, zoxide after `compinit`,
   and zsh-syntax-highlighting last. Every block is guarded on its tool
   being present, so the file silently adapts as you install or remove
   tools; no need to rerun `--enable` after a `pacman -S` or `brew install`.
2. If `~/.zshrc` does not already source that file, it appends one source
   line at the end, after saving a timestamped backup of your `~/.zshrc`.
   That is the only edit your own files ever get.

Keep that source line near the end of `~/.zshrc`: anything you load after
it breaks the "syntax highlighting last" rule.

`--enable` is deliberately additive: it never removes anything from your
config. If your `~/.zshrc` still loads oh-my-zsh or Powerlevel10k, they
stay in charge and the report flags it with a `[!!]` pointing to the full
migration below.

## Full migration: `install.sh`

`--enable` wires tools into the `~/.zshrc` you already have. If what you
have is an oh-my-zsh / Powerlevel10k setup you are trying to leave, or a
bare default, `install.sh` replaces `~/.zshrc` with the complete profile in
[`profiles/classic.zshrc`](profiles/classic.zshrc): sane options, shared
history with sensible dedup, proper keybindings (arrows do prefix history
search, Ctrl+arrows move by word), pushd-based directory navigation,
a curated set of git aliases compatible with oh-my-zsh muscle memory,
`clipcopy`/`clippaste` (macOS, Wayland or X11), a dynamic terminal title,
guarded Starship init, and the classic stack loaded last in the correct
order.

Safe by default: with no arguments it only prints the plan.

```sh
curl -sS https://raw.githubusercontent.com/carlosplanchon/zsh-classic-stack/main/install.sh | sh
```

To apply it (timestamped backup of your current `~/.zshrc` first):

```sh
curl -sS https://raw.githubusercontent.com/carlosplanchon/zsh-classic-stack/main/install.sh | sh -s -- --yes
```

What it deliberately does not do: it never deletes `~/.oh-my-zsh`,
`~/.p10k.zsh` or any theme files. Replacing the lines that loaded them is
enough to deactivate them, the backup restores everything, and you can
remove the leftovers by hand whenever you feel safe. Machine-specific
config (PATH additions, `EDITOR`, private aliases) belongs in
`~/.zshrc.local`, which the profile sources automatically: salvage those
lines from the backup after migrating. A fully commented starting point
ships in [`examples/zshrc.local`](examples/zshrc.local); copying it as-is
is a no-op until you uncomment what applies.

## What it knows, per system

| | Arch (pacman) | Debian/Ubuntu (apt) | Fedora (dnf) | Homebrew |
|---|---|---|---|---|
| starship | `starship` | official installer (packages lag, when they exist) | `starship` | `starship` |
| fzf | `fzf` | `fzf` | `fzf` | `fzf` |
| zoxide | `zoxide` | `zoxide` (lags; upstream suggests its script) | `zoxide` | `zoxide` |
| zsh-autosuggestions | `/usr/share/zsh/plugins/...` | `/usr/share/zsh-autosuggestions/...` | same path as Debian | `$(brew --prefix)/share/...` |
| zsh-syntax-highlighting | `/usr/share/zsh/plugins/...` | `/usr/share/zsh-syntax-highlighting/...` | same path as Debian | `$(brew --prefix)/share/...` |
| zsh-completions | `zsh-completions` (into fpath, zero config) | not packaged: clone | not packaged: clone | `zsh-completions` + `FPATH` line |

Details the script also knows about:

- **zsh-syntax-highlighting** must be sourced as the last line of `~/.zshrc`,
  after every other plugin.
- **zoxide** and **zsh-completions** interact with `compinit`: zoxide's
  `eval` line goes after it, the completions `fpath`/`FPATH` line before it.
- **fzf** shell integration is `source <(fzf --zsh)` on current versions;
  the script probes your binary and points to the manual setup when it
  predates `--zsh` (common with apt).
- On Arch, `zsh-completions` needs no zshrc line at all: its functions land
  in a directory that is already in `fpath`.

Sources: each tool's upstream install docs, the package indexes and file
lists of the distros (packages.debian.org, packages.ubuntu.com,
packages.fedoraproject.org, archlinux.org) and the Homebrew formula
caveats, checked 2026-07.

## Why a managed snippet instead of editing `~/.zshrc` freely

Shell setups are personal: a script that weaves lines into `~/.zshrc` has to
guess where your plugin manager, compinit call and prompt init live, and a
wrong guess breaks every future shell. This stack is extra hostile to blind
appending because its ordering rules conflict: completions go before
`compinit`, zoxide after it, syntax highlighting last of all. So `--enable`
never guesses: everything lives in one generated file where the order is
fixed, and your `~/.zshrc` gets a single, clearly labeled source line (with
a backup first). Reverting is deleting that line; the default mode stays
strictly report-only.

The one known cost: if your `~/.zshrc` already runs `compinit` before the
source line and the zsh-completions directory exists, the snippet runs
`compinit` a second time to pick it up, which adds a few milliseconds of
shell startup. Moving your own `compinit` out (the snippet runs it for you)
removes the double run.

## Detection notes

"Enabled" is a heuristic: the tool's name appearing anywhere in your
`~/.zshrc` (`$ZDOTDIR` respected), or the managed snippet being wired in.
That correctly covers package installs, oh-my-zsh `plugins=(...)` lists and
zinit/antigen lines, but a setup driven entirely from files outside `.zshrc`
(antidote's plugin file, for example) can show as not installed even though
it works. Worst case is an unnecessary suggestion.

## Related

- [starship-p10k-rainbow](https://github.com/carlosplanchon/starship-p10k-rainbow):
  the Starship preset this script grew out of. The prompt for the muscle
  memory; this stack for the rest of it.
- [sway-workstation](https://github.com/carlosplanchon/sway-workstation):
  the reproducible Sway desktop this shell lives in. Desktop, shell and
  prompt: the three repos compose a terminal-first workstation.

## License

[MIT](LICENSE)
