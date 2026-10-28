# Dotfiles

macOS setup for my Macs, work and personal: zsh with oh-my-zsh, Homebrew, git with signed commits, SSH between my machines, macOS settings, and a Claude Code baseline. Everything under `home/` is **symlinked** into `~`, so editing a dotfile edits the repo, and anything an installer appends shows up in `git status`.

Originally forked from [mathiasbynens/dotfiles](https://github.com/mathiasbynens/dotfiles); little of that remains.

## A new Mac

1. Sign in with your Apple ID (System Settings), so App Store apps can install later. Install Xcode separately if you need it.
2. Install the Command Line Tools, then clone:

   ```bash
   xcode-select --install
   ```

   ```bash
   git clone https://github.com/Vortec4800/dotfiles.git ~/dotfiles
   ```

3. Preview, then run:

   ```bash
   ~/dotfiles/bootstrap.sh --dry-run
   ```

   ```bash
   ~/dotfiles/bootstrap.sh
   ```

   It asks, once, whether this is a **work** or a **personal** Mac and for a short name (`mbp`, `studio`, `work-mbp`). Along the way it asks for:
   - an SSH key passphrase (stored in the Keychain)
   - a GitHub login in the browser, which uploads the key for authentication and signing
   - your commit name and email
   - App Store sign-in

   Stages can be run on their own: `./bootstrap.sh brew`, `./bootstrap.sh ssh git`, and so on (`--help` lists them).
4. Push this Mac's keys, so your other Macs trust it. Bootstrap writes them to `ssh/keys/` and `ssh/hosts/`, and at the end offers to commit and push them. If the clone uses HTTPS, it switches `origin` to SSH first, since GitHub has this Mac's key by then. To do it yourself instead:

   ```bash
   cd ~/dotfiles && git remote set-url origin git@github.com:Vortec4800/dotfiles.git && git add ssh && git commit -m "Add <name>'s SSH keys" && git pull --rebase && git push
   ```

   Then run `dotsync` on each of your other Macs.
5. On a personal Mac, the last stage offers to set up [devsync](https://github.com/Vortec4800/devsync) (private), which syncs `~/Projects` and `~/.claude` through Voyager.

### By hand

- **Tailscale:** rename this Mac in the admin console to its short name, so `ssh <name>` works from anywhere on the tailnet.
- **Voyager:** paste the output of `./bootstrap.sh ssh --print-keys` into Unraid's Users → root → SSH authorized keys.
- **Work Macs on GitLab:** add `~/.ssh/id_ed25519.pub` under Preferences → SSH Keys, usage "Authentication & Signing".
- **Full Disk Access** for Terminal (Privacy & Security), before `macos.sh` runs, so it can set Safari and Mail.
- iCloud Drive's "Desktop & Documents Folders", and the Dock's app layout.
- Apps no script can install:
  - iPad apps from the App Store: CARROT, Callsheet, Overcast, Frame TV Pics, Channels
  - apps with no Homebrew cask: Firefoo, HueForge, UniFi, TurboTax
  - Xcode
- Work Macs: Office, Teams, Defender and the like come from IT's device management, never from the Brewfiles.

## Day to day

| Task | How |
|---|---|
| Change a dotfile | Edit it (through `~` or in `~/dotfiles/home/`), commit, push, then `dotsync` elsewhere |
| Pick up changes on another Mac | `dotsync` (pulls, relinks, refreshes SSH keys and hosts) |
| An installer appended to `~/.zshrc` | It shows in `git status`; move PATH lines into `home/.path`, private bits into `~/.extra` |
| Add or remove an app | Edit `Brewfile`, `Brewfile.apps`, `Brewfile.work` or `Brewfile.personal`, then `./bootstrap.sh brew` |
| Update everything | `update` (Homebrew, npm globals, list macOS updates) |
| Trust a server that can't run bootstrap | `./bootstrap.sh ssh --add-host <name> [hostname [user]]`, then commit `ssh/hosts/` |
| Retire a Mac | Delete its files from `ssh/keys/` and `ssh/hosts/`, push, `dotsync` everywhere; remove its key from GitHub and Voyager |
| Refresh the Claude baseline | `./bootstrap.sh claude --capture`, review the diff, commit |

`nvm` still works out of habit: it forwards to [fnm](https://github.com/Schniz/fnm) and prints the fnm command it ran. fnm switches Node versions on `cd` into a folder with `.nvmrc` or `.node-version`.

## What lives where

| In the repo | What it is |
|---|---|
| `home/` | Dotfiles, symlinked into `~` by `./bootstrap.sh link`. Existing files are moved to `~/.dotfiles-backup/<timestamp>/` first |
| `Brewfile`, `Brewfile.apps` | Command-line tools and apps for every Mac |
| `Brewfile.work`, `Brewfile.personal` | Per-profile extras |
| `macos.sh` | macOS settings. New choices are marked; options not chosen are commented out |
| `claude/` | Claude Code baseline (`settings.json`, `CLAUDE.md`, `rules/`), **copied** into `~/.claude` only where a file is missing |
| `ssh/` | Public keys only: each machine's user key (`keys/`), host key (`hosts/`), and GitHub's host keys |
| `bootstrap.sh`, `lib/` | Setup stages; `--dry-run` shows everything and changes nothing |

| Outside the repo, per Mac | What it is |
|---|---|
| `~/.extra` | Machine-local or private shell settings, sourced last |
| `~/.gitconfig.local` | Commit name, email and signing key (written by `./bootstrap.sh git`) |
| `~/.config/git/allowed_signers` | Lets `git log --show-signature` verify your own commits |
| `~/.config/dotfiles/machine.env` | This Mac's profile and short name |
| `~/.config/dotfiles/private-patterns` | Regexes for names that must never reach this public repo; `claude --capture` refuses to copy matching lines |
| `~/.npmrc` | Registry tokens. Never commit it; put tokens in `~/.extra` as `NPM_TOKEN`, or use `aws codeartifact login` |

**This repository is public.** Company, project, host and email names stay out of it: identity goes in `~/.gitconfig.local`, and the Claude baseline is sanitized.

## Shell helpers

oh-my-zsh provides navigation, `ls` aliases and `g` for git.

- Aliases: `dl`, `dt`, `h`, `path`, `week`, `timer`, `update`, `dotsync`, `ip`, `localip`, `flush`, `lscleanup`, `c`, `cleanup`, `plistbuddy`, `map`, `reload`
- Functions: `calc`, `mkd`, `targz`, `fs`, `dataurl`, `server`, `digga`, `getcertnames`, `o`, `nvm`
