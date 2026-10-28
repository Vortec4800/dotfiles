# shellcheck shell=bash
# shellcheck disable=SC2034 # BACKED_UP and REPO_CHANGED are read by bootstrap.sh
# Shared helpers for bootstrap.sh. Written for macOS's /bin/bash 3.2, which is
# all a new Mac has before Homebrew: no associative arrays, no `${var,,}`.

DRY_RUN=${DRY_RUN:-0}
STATE_DIR="$HOME/.config/dotfiles"
STATE_FILE="$STATE_DIR/machine.env"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
BACKED_UP=0
REPO_CHANGED=0
PROFILE=""
ALIAS=""

if [ -t 1 ]; then
	C_BOLD=$'\033[1m' C_DIM=$'\033[2m' C_RED=$'\033[31m' C_GREEN=$'\033[32m' C_YELLOW=$'\033[33m' C_OFF=$'\033[0m'
else
	C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_OFF=''
fi

hdr()  { printf '\n%s== %s ==%s\n' "$C_BOLD" "$*" "$C_OFF"; }
info() { printf '   %s\n' "$*"; }
ok()   { printf ' %s✓%s %s\n' "$C_GREEN" "$C_OFF" "$*"; }
warn() { printf ' %s!%s %s\n' "$C_YELLOW" "$C_OFF" "$*" >&2; }
die()  { printf ' %s✗ %s%s\n' "$C_RED" "$*" "$C_OFF" >&2; exit 1; }
dry()  { printf '   %s[dry-run]%s %s\n' "$C_DIM" "$C_OFF" "$*"; }

# ~/… form of a path, for messages
tildify() {
	case $1 in
		"$HOME"/*) printf '~/%s' "${1#"$HOME"/}" ;;
		*) printf '%s' "$1" ;;
	esac
}

# run CMD [ARGS…]: run it, or in dry-run mode only print it
run() {
	if [ "$DRY_RUN" = 1 ]; then
		dry "$(printf '%q ' "$@")"
		return 0
	fi
	"$@"
}

# confirm "Question?" [y|n]: 0 for yes. A dry run answers yes, to show the whole path.
confirm() {
	local q=$1 def=${2:-y} hint ans=""
	if [ "$def" = y ]; then hint='[Y/n]'; else hint='[y/N]'; fi
	if [ "$DRY_RUN" = 1 ]; then
		dry "would ask: $q $hint (assuming yes)"
		return 0
	fi
	printf '   %s %s ' "$q" "$hint"
	read -r ans </dev/tty || ans=""
	case $ans in
		[Yy]*) return 0 ;;
		[Nn]*) return 1 ;;
		"") [ "$def" = y ] ;;
		*) return 1 ;;
	esac
}

# ask VAR "Prompt" [default]: read an answer into VAR
ask() {
	# Prefixed names, so they can't shadow the caller's variable
	local _ask_var=$1 _ask_q=$2 _ask_def=${3:-} _ask_ans=""
	if [ "$DRY_RUN" = 1 ]; then
		dry "would ask: $_ask_q${_ask_def:+ [$_ask_def]}"
		_ask_ans=$_ask_def
	else
		printf '   %s%s: ' "$_ask_q" "${_ask_def:+ [$_ask_def]}"
		read -r _ask_ans </dev/tty || _ask_ans=""
		[ -n "$_ask_ans" ] || _ask_ans=$_ask_def
	fi
	printf -v "$_ask_var" '%s' "$_ask_ans"
}

# Machine state: profile (work/personal) and SSH alias, kept outside the repo.
state_get() {
	if [ -f "$STATE_FILE" ]; then
		grep "^$1=" "$STATE_FILE" | tail -n 1 | cut -d= -f2- || true
	fi
}

load_state() {
	PROFILE=${DOTFILES_PROFILE:-$(state_get PROFILE)}
	ALIAS=${DOTFILES_ALIAS:-$(state_get ALIAS)}
}

save_state() {
	printf 'PROFILE=%s\nALIAS=%s\n' "$PROFILE" "$ALIAS" | write_file "$STATE_FILE" 644
}

# Move a file or folder into this run's backup folder, keeping its path under ~
backup() {
	local path=$1 rel dest
	rel=${path#"$HOME"/}
	dest="$BACKUP_DIR/$rel"
	BACKED_UP=1
	if [ "$DRY_RUN" = 1 ]; then
		dry "would back up $(tildify "$path") → $(tildify "$dest")"
		return 0
	fi
	mkdir -p "$(dirname "$dest")"
	mv "$path" "$dest"
	info "backed up $(tildify "$path") → $(tildify "$dest")"
}

# Like backup, but leaves the original in place (for files edited in place)
backup_copy() {
	local path=$1 rel dest
	rel=${path#"$HOME"/}
	dest="$BACKUP_DIR/$rel"
	BACKED_UP=1
	if [ "$DRY_RUN" = 1 ]; then
		dry "would save a copy of $(tildify "$path") → $(tildify "$dest")"
		return 0
	fi
	mkdir -p "$(dirname "$dest")"
	cp -p "$path" "$dest"
	info "saved a copy of $(tildify "$path") → $(tildify "$dest")"
}

# write_file DEST [MODE] < content: replace DEST only when the content changed.
# Files inside the repo are tracked in REPO_CHANGED so the summary can say so.
write_file() {
	local dest=$1 mode=${2:-644} tmp
	tmp=$(mktemp "${TMPDIR:-/tmp}/dotfiles.XXXXXX")
	cat >"$tmp"
	if [ -f "$dest" ] && cmp -s "$tmp" "$dest"; then
		rm -f "$tmp"
		ok "$(tildify "$dest") is up to date"
		return 0
	fi
	case $dest in "$DOTFILES"/*) REPO_CHANGED=1 ;; esac
	if [ "$DRY_RUN" = 1 ]; then
		dry "would write $(tildify "$dest") ($(wc -l <"$tmp" | tr -d ' ') lines)"
		rm -f "$tmp"
		return 0
	fi
	mkdir -p "$(dirname "$dest")"
	chmod "$mode" "$tmp"
	mv "$tmp" "$dest"
	ok "wrote $(tildify "$dest")"
}

require_profile() {
	if [ -z "$PROFILE" ] || [ -z "$ALIAS" ]; then
		stage_profile
	fi
}
