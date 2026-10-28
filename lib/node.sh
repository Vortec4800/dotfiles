# shellcheck shell=bash
# Stage: node. Node versions via fnm, and global npm packages on the default one.

NODE_VERSIONS="22 20 24"                # the first one becomes the default
NPM_GLOBALS_ALL="firebase-tools"
NPM_GLOBALS_WORK="aws-cdk"
NPM_GLOBALS_PERSONAL=""

stage_node() {
	hdr "Node (fnm)"
	require_profile
	if ! command -v fnm >/dev/null 2>&1; then
		if [ "$DRY_RUN" = 1 ]; then
			dry "fnm isn't installed yet; the brew stage installs it"
		else
			warn "fnm isn't installed; run ./bootstrap.sh brew first"
			return 0
		fi
	fi
	local v default=${NODE_VERSIONS%% *} globals="$NPM_GLOBALS_ALL"
	for v in $NODE_VERSIONS; do
		run fnm install "$v"
	done
	run fnm default "$default"
	if [ "$PROFILE" = work ]; then
		globals="$globals $NPM_GLOBALS_WORK"
	else
		globals="$globals $NPM_GLOBALS_PERSONAL"
	fi
	# shellcheck disable=SC2086 # one argument per package
	set -- $globals
	# A failed npm install (often a root-owned ~/.npm) shouldn't stop the later stages
	if [ $# -gt 0 ] && ! run fnm exec --using "$default" npm install --global "$@"; then
		warn "npm couldn't install the global packages: $*"
		info "Fix the npm error above, then run ./bootstrap.sh node"
	fi
}
