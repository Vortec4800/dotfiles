#!/usr/bin/env bash
# Set up this Mac from ~/dotfiles, or bring it back in line. Safe to run again.
#
#   ./bootstrap.sh                  every stage, in order
#   ./bootstrap.sh link ssh         only these stages
#   ./bootstrap.sh --dry-run        show what would happen; change nothing
#
# Stages, in the order `all` runs them:
#   xcode      Xcode Command Line Tools
#   profile    is this a work or a personal Mac, and its short name (asked once)
#   brew       Homebrew, then Brewfile + Brewfile.apps + Brewfile.<profile>
#   link       symlink everything in home/ into ~ (existing files are backed up)
#   zsh        oh-my-zsh, if missing
#   ssh        key, GitHub, logins between your machines, key-only sshd
#   git        ~/.gitconfig.local identity and commit signing
#   node       Node versions with fnm, global npm packages
#   claude     seed ~/.claude with the baseline in claude/ (never overwrites)
#   macos      macos.sh
#   devsync    personal Macs: clone and set up ~/devsync
#
# Other commands:
#   sync                           pull this repo, then refresh links and SSH keys/hosts (alias: dotsync)
#   ssh-hosts                      refresh SSH keys, known hosts and host aliases from the repo
#   ssh --print-keys               print every machine's public key (to paste into a server)
#   ssh --add-host ALIAS [HOST [USER]]
#                                  trust a machine that can't run this, e.g. voyager voyager root
#   claude --capture               refresh claude/ from this Mac's ~/.claude, for review
#
# Backups go to ~/.dotfiles-backup/<timestamp>/. Machine state lives in
# ~/.config/dotfiles/machine.env (DOTFILES_PROFILE / DOTFILES_ALIAS override it).
# When this Mac's SSH keys in the repo are new or changed, the end of any run
# offers to commit and push them.

set -eu

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# common.sh first: the stage files use its settings and helpers
# shellcheck source=lib/common.sh
. "$DOTFILES/lib/common.sh"
for lib in "$DOTFILES"/lib/*.sh; do
	if [ "$lib" != "$DOTFILES/lib/common.sh" ]; then
		# shellcheck source=/dev/null
		. "$lib"
	fi
done

ALL_STAGES="xcode profile brew link zsh ssh git node claude macos devsync"

usage() {
	awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}

stage_sync() {
	hdr "Updating ~/dotfiles"
	run git -C "$DOTFILES" pull --ff-only
	# Run the rest from the freshly pulled scripts
	if [ "$DRY_RUN" = 1 ]; then
		exec "$DOTFILES/bootstrap.sh" --dry-run link ssh-hosts
	fi
	exec "$DOTFILES/bootstrap.sh" link ssh-hosts
}

main() {
	local stages="" explicit=0 extra="" extra_args=() stage
	while [ $# -gt 0 ]; do
		case $1 in
			-n|--dry-run) DRY_RUN=1 ;;
			-h|--help) usage; exit 0 ;;
			--print-keys) extra=print-keys ;;
			--capture) extra=capture ;;
			--add-host)
				extra=add-host
				shift
				while [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; do
					extra_args+=("$1")
					shift
				done
				continue
				;;
			all) stages="$stages $ALL_STAGES" ;;
			xcode|profile|brew|link|zsh|ssh|git|node|claude|macos|devsync|sync|ssh-hosts)
				stages="$stages $1"
				explicit=1
				;;
			*) die "unknown argument: $1 (see ./bootstrap.sh --help)" ;;
		esac
		shift
	done

	[ "$(uname -s)" = Darwin ] || die "This bootstrap is for macOS."
	load_state
	if [ "$DRY_RUN" = 1 ]; then
		info "Dry run: nothing will be changed."
	fi

	case $extra in
		print-keys) ssh_print_keys; return 0 ;;
		add-host) ssh_add_host ${extra_args[@]+"${extra_args[@]}"}; return 0 ;;
		capture) claude_capture; return 0 ;;
	esac

	[ -n "$stages" ] || stages=$ALL_STAGES
	for stage in $stages; do
		# devsync isn't part of a work Mac's setup at all
		if [ "$stage" = devsync ] && [ "$explicit" = 0 ] && [ "$PROFILE" = work ]; then
			continue
		fi
		case $stage in
			ssh-hosts) stage_ssh_hosts ;;
			*) "stage_$stage" ;;
		esac
	done

	hdr "Done"
	if [ "$DRY_RUN" = 1 ]; then
		info "Dry run: nothing was changed."
		if [ "$BACKED_UP" = 1 ]; then
			info "A real run would move replaced files to $(tildify "$BACKUP_DIR")"
		fi
		if [ "$REPO_CHANGED" = 1 ]; then
			info "A real run would add this Mac's SSH keys to ~/dotfiles (ssh/keys, ssh/hosts) and offer to push them."
		fi
	elif [ "$BACKED_UP" = 1 ]; then
		info "Replaced files are in $(tildify "$BACKUP_DIR")"
	fi
	# Whenever this Mac's key files are new or changed, from this run or an earlier one
	ssh_publish_keys
}

main "$@"
