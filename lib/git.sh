# shellcheck shell=bash
# Stage: git. Writes this machine's identity and signing setup outside the repo:
# ~/.gitconfig.local (included by ~/.gitconfig) and ~/.config/git/allowed_signers.

stage_git() {
	hdr "Git identity and commit signing"
	require_profile
	local local_cfg="$HOME/.gitconfig.local"
	local signers="$HOME/.config/git/allowed_signers"
	local pub="$HOME/.ssh/id_ed25519.pub"
	local cur_name cur_email name="" email="" tmp

	cur_name=$(git config --file "$local_cfg" user.name 2>/dev/null || true)
	cur_email=$(git config --file "$local_cfg" user.email 2>/dev/null || true)
	if [ -n "$cur_name" ] && [ -n "$cur_email" ]; then
		ok "$(tildify "$local_cfg"): $cur_name <$cur_email>"
		if confirm "Keep this identity?" y; then
			name=$cur_name
			email=$cur_email
		fi
	fi
	if [ -z "$name" ]; then
		ask name "Your name for commits" "$cur_name"
		ask email "Commit email for this $PROFILE Mac" "$cur_email"
	fi
	[ -n "$name" ] || name="<your name>"
	[ -n "$email" ] || email="<your email>"

	tmp=$(mktemp "${TMPDIR:-/tmp}/dotfiles.XXXXXX")
	printf '# This Mac'\''s git identity (%s profile), written by ~/dotfiles/bootstrap.sh git.\n# Untracked on purpose: ~/.gitconfig includes it.\n' "$PROFILE" >"$tmp"
	git config --file "$tmp" user.name "$name"
	git config --file "$tmp" user.email "$email"
	# shellcheck disable=SC2088 # a literal ~ for git to expand
	git config --file "$tmp" user.signingkey "~/.ssh/id_ed25519.pub"
	write_file "$local_cfg" 600 <"$tmp"
	rm -f "$tmp"

	if [ -f "$pub" ]; then
		printf '%s namespaces="git" %s\n' "$email" "$(cut -d' ' -f1,2 "$pub")" | write_file "$signers" 644
	else
		warn "No SSH key yet, so signed commits will fail. Run ./bootstrap.sh ssh, then ./bootstrap.sh git."
	fi
	if [ "$PROFILE" = work ]; then
		info "If work repos live on GitLab, add the same key there too (Preferences → SSH Keys,"
		info "usage type \"Authentication & Signing\") so GitLab shows the commits as verified."
	fi
}
