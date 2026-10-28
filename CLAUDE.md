# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Cory's macOS dotfiles for work and personal Macs: zsh + oh-my-zsh (`steeef`), Homebrew Brewfiles, git with SSH-signed commits, SSH between his machines, `macos.sh`, and a Claude Code baseline. Forked long ago from mathiasbynens/dotfiles; don't merge or "sync" upstream.

**The repository is public.** Never commit company, project, host or email names, tokens, IP addresses or tailnet domains. Per-machine and private settings live outside the repo (see the README's "What lives where").

## How it deploys

`./bootstrap.sh [stage…] [--dry-run]` runs stages in this order: `xcode profile brew link zsh ssh git node claude macos devsync`. `--help` lists them and the extra commands (`sync`, `ssh-hosts`, `ssh --print-keys`, `ssh --add-host`, `claude --capture`).

- `link` symlinks every file under `home/` to the same path under `~`, moving anything in the way to `~/.dotfiles-backup/<timestamp>/`. Edits through `~` land in the repo.
- `claude/` is **copied** into `~/.claude` only where a file is missing; never linked. On personal Macs devsync syncs `~/.claude`, and its `setup.sh` rewrites `settings.json`.
- Machine state (profile `work`/`personal`, SSH alias) is in `~/.config/dotfiles/machine.env`; `DOTFILES_PROFILE` and `DOTFILES_ALIAS` override it.
- Generated, never hand-edited: `~/.gitconfig.local`, `~/.config/git/allowed_signers`, `~/.ssh/known_hosts.dotfiles`, `~/.ssh/config.d/dotfiles-hosts`, and the marked block in `~/.ssh/authorized_keys`.

**Don't run `bootstrap.sh` (except with `--dry-run`) or `macos.sh` yourself.** They change `~`, prompt on `/dev/tty`, need `sudo`, and `macos.sh` restarts Finder and the Dock. `--dry-run` is safe and is the way to show what a run would do. To exercise stages for real, run them from a scratch copy of the repo with `HOME` pointed at a scratch folder.

## Writing the scripts

- `bootstrap.sh` and `lib/*.sh` must run on macOS's **`/bin/bash` 3.2** (a new Mac has nothing newer): no associative arrays, `mapfile`, `${var,,}`, or `${arr[@]}` on an empty array under `set -u`. They run with `set -eu`.
- Anything that sets `REPO_CHANGED` or `BACKED_UP` (`write_file`, `backup`) must not be the last command of a pipeline, which runs in a subshell; feed it with `< <(…)` or `<<<` instead.
- Every change to `~` or the repo goes through `run`, `write_file`, `backup` or `backup_copy`, so `--dry-run` stays honest. Prompts go through `confirm` and `ask`.
- The `home/` shell files are zsh only. `home/.path` uses `typeset -U path` and `(N-/)`; installers' PATH lines belong there, not in `.zshrc` or `.zprofile`.

## Checking a change

```bash
for f in bootstrap.sh macos.sh lib/*.sh; do /bin/bash -n "$f"; done
```

```bash
shellcheck -x bootstrap.sh macos.sh lib/*.sh
```

```bash
for f in home/.zshrc home/.zprofile home/.path home/.exports home/.aliases home/.functions; do zsh -n "$f"; done
```

```bash
git config --file home/.gitconfig --list >/dev/null
```

```bash
./bootstrap.sh --dry-run
```

`shellcheck` comes from the Brewfile; without it, `uvx --from shellcheck-py shellcheck` works. `.shellcheckrc` disables SC2088, because messages print `~/…` on purpose. To try a function without deploying: `zsh -c 'source home/.functions; <name> <args>'`.

The Bash tool's shell is built from the live profile. On a Mac still running the old copied dotfiles, `diff` there is the old `git diff --no-index` function, so use `command diff`.

## Conventions

- `.editorconfig`: tabs, LF, final newline, trim trailing whitespace. `home/.editorconfig` links to it.
- Commit messages: short, imperative, describing the change.
- `claude/settings.json` holds only the allowlisted keys in `CLAUDE_SETTINGS_FILTER` (`lib/claude.sh`). Before committing anything under `claude/`, check it for work identifiers.
