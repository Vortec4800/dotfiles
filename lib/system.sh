# shellcheck shell=bash
# Stages: xcode, profile, brew, zsh, macos

stage_xcode() {
	hdr "Xcode Command Line Tools"
	if xcode-select -p >/dev/null 2>&1; then
		ok "installed ($(xcode-select -p))"
		return 0
	fi
	warn "not installed; macOS will show an install dialog"
	run xcode-select --install
	if [ "$DRY_RUN" != 1 ]; then
		die "Finish the Command Line Tools install, then run ./bootstrap.sh again."
	fi
}

stage_profile() {
	hdr "This Mac"
	if [ -n "$PROFILE" ] && [ -n "$ALIAS" ]; then
		ok "profile $PROFILE, alias $ALIAS ($(tildify "$STATE_FILE"))"
		return 0
	fi
	local answer
	while [ -z "$PROFILE" ]; do
		ask answer "Is this a work or a personal Mac? (work/personal)"
		case $answer in
			work|personal) PROFILE=$answer ;;
			*)
				if [ "$DRY_RUN" = 1 ]; then
					PROFILE=personal
					dry "using profile personal (set DOTFILES_PROFILE=work to preview a work Mac)"
				else
					warn "type work or personal"
				fi
				;;
		esac
	done
	while [ -z "$ALIAS" ]; do
		ask answer "Short name for this Mac, used for SSH between your machines (e.g. mbp, studio, work-mbp)"
		case $answer in
			[a-z0-9]*[!a-z0-9-]*|"") ;;
			[a-z0-9]*) ALIAS=$answer; continue ;;
		esac
		if [ "$DRY_RUN" = 1 ]; then
			ALIAS=this-mac
			dry "using alias this-mac (set DOTFILES_ALIAS to preview another)"
		else
			warn "use lowercase letters, digits and hyphens"
		fi
	done
	save_state
}

# The Brewfiles for this profile, in install order
brewfiles() {
	printf '%s\n' "$DOTFILES/Brewfile" "$DOTFILES/Brewfile.apps" "$DOTFILES/Brewfile.$PROFILE"
}

# brewfile_lines main|mas: the entries from every Brewfile for this profile.
# "main" puts all taps first, then formulae and casks; "mas" is App Store apps only.
brewfile_lines() {
	local files=()
	while IFS= read -r f; do files+=("$f"); done < <(brewfiles)
	if [ "$1" = mas ]; then
		grep -h '^[[:space:]]*mas ' "${files[@]}" || true
	else
		grep -h '^[[:space:]]*tap ' "${files[@]}" || true
		grep -hvE '^[[:space:]]*(tap |mas |#|$)' "${files[@]}" || true
	fi
}

# bundle LABEL < Brewfile lines
bundle() {
	local lines
	lines=$(cat)
	if [ -z "$lines" ]; then
		info "nothing to install for $1"
		return 0
	fi
	if [ "$DRY_RUN" = 1 ]; then
		dry "brew bundle --file=- with $1:"
		printf '%s\n' "$lines" | sed 's/^/          /'
		return 0
	fi
	printf '%s\n' "$lines" | brew bundle --file=-
}

# Apps installed by hand make `brew install --cask` refuse to overwrite them.
# Offer `--adopt`, which takes them over when the installed version matches.
brew_offer_adopt() {
	command -v brew >/dev/null 2>&1 || return 0
	command -v jq >/dev/null 2>&1 || return 0
	local casks installed token app adopt=""
	casks=$(brewfile_lines main | sed -n 's/^[[:space:]]*cask "\([^"]*\)".*/\1/p')
	[ -n "$casks" ] || return 0
	installed=" $(brew list --cask -1 2>/dev/null | tr '\n' ' ') "
	while IFS=$'\t' read -r token app; do
		case $installed in *" $token "*) continue ;; esac
		if [ -e "/Applications/$app" ]; then
			adopt="$adopt $token"
		fi
	done < <(
		# shellcheck disable=SC2086 # one argument per cask
		brew info --cask --json=v2 $casks 2>/dev/null |
			jq -r '.casks[] | .token as $t
				| ([.artifacts[] | objects | .app? // empty | .[] | strings] | first) as $a
				| select($a != null) | "\($t)\t\($a)"'
	)
	[ -n "$adopt" ] || return 0
	info "Already in /Applications but not managed by Homebrew:$adopt"
	info "brew bundle reports these as failed unless Homebrew adopts them."
	confirm "Try to adopt them now? (works when the installed version matches; a failure leaves the app as it is)" y || return 0
	for token in $adopt; do
		run brew install --cask --adopt "$token" || warn "couldn't adopt $token; it stays as installed"
	done
}

stage_brew() {
	hdr "Homebrew"
	require_profile
	if [ ! -x /opt/homebrew/bin/brew ]; then
		if [ "$DRY_RUN" = 1 ]; then
			dry "would run the official Homebrew installer"
		else
			/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
		fi
	fi
	if [ -x /opt/homebrew/bin/brew ]; then
		eval "$(/opt/homebrew/bin/brew shellenv)"
		ok "$(brew --version | head -n 1)"
	fi
	info "Brewfiles: $(brewfiles | sed "s|^$DOTFILES/||" | tr '\n' ' ')"

	brew_offer_adopt
	if ! brewfile_lines main | bundle "formulae and casks"; then
		warn "some formulae or casks failed; the rest are installed. Rerun ./bootstrap.sh brew to retry."
	fi

	local mas
	mas=$(brewfile_lines mas)
	[ -n "$mas" ] || return 0
	info "App Store apps install only when you're signed in to the App Store with the Apple ID"
	info "that already owns them. macOS doesn't let scripts sign in or check, so the App Store opens now."
	run open -a "App Store"
	if ! confirm "Signed in to the App Store? Install the App Store apps" y; then
		info "skipped; run ./bootstrap.sh brew again once you're signed in"
		return 0
	fi
	until printf '%s\n' "$mas" | bundle "App Store apps"; do
		confirm "Some App Store apps didn't install (not signed in, or not owned by this Apple ID). Try again?" n || break
	done
}

stage_zsh() {
	hdr "oh-my-zsh"
	if [ -d "$HOME/.oh-my-zsh" ]; then
		ok "installed"
		return 0
	fi
	if [ "$DRY_RUN" = 1 ]; then
		dry "would install oh-my-zsh, keeping the linked ~/.zshrc"
		return 0
	fi
	KEEP_ZSHRC=yes RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
}

stage_macos() {
	hdr "macOS settings"
	info "Runs macos.sh: system settings and Touch ID for sudo; restarts Finder, the Dock and the menu bar."
	if [ "$DRY_RUN" = 1 ]; then
		dry "would run $(tildify "$DOTFILES/macos.sh")"
		return 0
	fi
	if ! confirm "Run macos.sh now?" y; then
		info "skipped"
		return 0
	fi
	"$DOTFILES/macos.sh"
}
