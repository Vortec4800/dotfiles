# shellcheck shell=bash
# Stage: devsync (personal Macs only). Hands over to the devsync project, which
# syncs ~/Projects and ~/.claude through Syncthing and Voyager.

DEVSYNC_DIR="$HOME/devsync"
DEVSYNC_REPO="git@github.com:Vortec4800/devsync.git"

devsync_instructions() {
	info "To set up devsync later:"
	info "  git clone $DEVSYNC_REPO ~/devsync   (once GitHub has this Mac's key)"
	info "  ~/devsync/setup.sh"
	info "Details: ~/devsync/INSTALL.md, Phase 4 (each additional Mac)."
}

github_ssh_ok() {
	local out
	out=$(ssh -o BatchMode=yes -o ConnectTimeout=8 -T git@github.com 2>&1 || true)
	case $out in *"successfully authenticated"*) return 0 ;; esac
	return 1
}

# devsync's setup moves existing ~/.claude items aside on a new Mac so Voyager's
# copies arrive cleanly, but its list leaves out rules/, which it does sync. A
# baseline rules/ seeded by the claude stage would then clash with Voyager's.
devsync_rules_gap() {
	[ -d "$HOME/.claude/rules" ] || return 0
	[ ! -e "$HOME/.claude/.stfolder" ] || return 0
	if grep -qE 'for item in .*[[:space:]]rules([[:space:];]|$)' "$DEVSYNC_DIR/setup.sh" 2>/dev/null; then
		return 0
	fi
	warn "devsync's setup doesn't move ~/.claude/rules aside, so the baseline copy would clash with Voyager's."
	if confirm "Move ~/.claude/rules into the backup folder first? (Voyager's copy replaces it)" y; then
		backup "$HOME/.claude/rules"
	fi
}

stage_devsync() {
	hdr "devsync"
	require_profile
	if [ "$PROFILE" != personal ]; then
		info "devsync is for personal Macs only; skipping"
		return 0
	fi
	if [ -d "$DEVSYNC_DIR/.git" ]; then
		ok "$(tildify "$DEVSYNC_DIR") is here"
	elif [ "$DRY_RUN" = 1 ]; then
		dry "would clone $DEVSYNC_REPO into ~/devsync (needs this Mac's key on GitHub)"
	elif github_ssh_ok; then
		git clone "$DEVSYNC_REPO" "$DEVSYNC_DIR"
	else
		warn "Can't reach GitHub over SSH yet, and devsync's repository is private."
		devsync_instructions
		return 0
	fi
	devsync_rules_gap
	if ! confirm "Run devsync setup now? It needs Voyager reachable (home network or Tailscale) and Voyager's API key." y; then
		devsync_instructions
		return 0
	fi
	if [ "$DRY_RUN" = 1 ]; then
		dry "would run ~/devsync/setup.sh"
		return 0
	fi
	"$DEVSYNC_DIR/setup.sh" || { warn "devsync setup didn't finish."; devsync_instructions; }
}
