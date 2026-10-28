# shellcheck shell=bash
# Stage: claude. Seeds ~/.claude with the baseline in claude/ (settings.json,
# CLAUDE.md, rules/). Copies, never links: Claude Code edits these files, and on
# personal Macs devsync syncs them, so neither should write into this repo.

CLAUDE_SRC="$DOTFILES/claude"
CLAUDE_DEST="$HOME/.claude"
# The only settings.json keys that may enter the public repo
# shellcheck disable=SC2016 # a jq program, not shell
CLAUDE_SETTINGS_FILTER='{
	"$schema", cleanupPeriodDays, includeCoAuthoredBy,
	permissions: (if .permissions.defaultMode then {defaultMode: .permissions.defaultMode} else null end),
	statusLine, enabledPlugins, extraKnownMarketplaces, alwaysThinkingEnabled, effortLevel,
	modelSettings, tui, voice, skipWorkflowUsageWarning, theme, agentPushNotifEnabled, voiceEnabled
} | with_entries(select(.value != null))'
PRIVATE_PATTERNS="$STATE_DIR/private-patterns"

stage_claude() {
	hdr "Claude Code baseline"
	local src rel dest
	while IFS= read -r src; do
		rel=${src#"$CLAUDE_SRC/"}
		dest="$CLAUDE_DEST/$rel"
		if [ ! -e "$dest" ]; then
			if [ "$DRY_RUN" = 1 ]; then
				dry "would copy $(tildify "$src") → ~/.claude/$rel"
			else
				mkdir -p "$(dirname "$dest")"
				cp "$src" "$dest"
				if [ "$rel" = settings.json ]; then
					chmod 600 "$dest"
				fi
				ok "copied ~/.claude/$rel"
			fi
		elif cmp -s "$src" "$dest"; then
			ok "~/.claude/$rel matches the baseline"
		else
			info "~/.claude/$rel differs from the baseline; keeping yours."
			info "  compare: diff -u $(tildify "$src") ~/.claude/$rel"
		fi
	done < <(find "$CLAUDE_SRC" -type f ! -name .DS_Store | sort)
}

# capture_write DEST < content: write into the repo unless a line matches a private pattern
capture_write() {
	local dest=$1 tmp hits
	tmp=$(mktemp "${TMPDIR:-/tmp}/dotfiles.XXXXXX")
	cat >"$tmp"
	if [ -s "$PRIVATE_PATTERNS" ]; then
		hits=$(grep -nE -f "$PRIVATE_PATTERNS" "$tmp" || true)
		if [ -n "$hits" ]; then
			warn "Not written: $(tildify "$dest"). These lines match $(tildify "$PRIVATE_PATTERNS"):"
			printf '%s\n' "$hits" | sed 's/^/      /' >&2
			info "  Edit the repo copy by hand instead; see what changed with: diff -u $(tildify "$dest") <the ~/.claude file>"
			rm -f "$tmp"
			return 0
		fi
	fi
	write_file "$dest" 644 <"$tmp"
	rm -f "$tmp"
}

# ./bootstrap.sh claude --capture: refresh claude/ from this Mac's ~/.claude
claude_capture() {
	hdr "Refreshing the Claude baseline from ~/.claude"
	command -v jq >/dev/null 2>&1 || die "jq is required (brew install jq)"
	if [ -f "$CLAUDE_DEST/settings.json" ]; then
		jq "$CLAUDE_SETTINGS_FILTER" "$CLAUDE_DEST/settings.json" | capture_write "$CLAUDE_SRC/settings.json"
	fi
	if [ ! -s "$PRIVATE_PATTERNS" ]; then
		warn "No $(tildify "$PRIVATE_PATTERNS"), so CLAUDE.md and rules/ were not copied into the public repo."
		info "Create it with one extended regex per line for anything that must never be published"
		info "(company, project, product and host names), then run this again."
	else
		local f
		for f in "$CLAUDE_DEST/CLAUDE.md" "$CLAUDE_DEST"/rules/*.md; do
			if [ -f "$f" ]; then
				capture_write "$CLAUDE_SRC/${f#"$CLAUDE_DEST/"}" <"$f"
			fi
		done
	fi
	git -C "$DOTFILES" status --short -- claude
	info "Nothing is committed. Review with: git -C ~/dotfiles diff -- claude"
}
