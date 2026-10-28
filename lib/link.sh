# shellcheck shell=bash
# Stage: link. Every file under home/ becomes a symlink at the same path under ~.

# Files the old rsync bootstrap copied into ~ that nothing uses any more
LEGACY_FILES=".osx .gdbinit .gemrc .gvimrc .screenrc .inputrc .gitattributes .gitignore_global"

ensure_parent() {
	local dir
	dir=$(dirname "$1")
	[ -d "$dir" ] && return 0
	run mkdir -p "$dir"
	case $dir in
		"$HOME/.ssh"|"$HOME/.ssh/"*) run chmod 700 "$HOME/.ssh" ;;
	esac
}

stage_link() {
	hdr "Linking dotfiles into ~"
	local src rel dest linked=0
	while IFS= read -r src; do
		rel=${src#"$DOTFILES/home/"}
		dest="$HOME/$rel"
		if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
			continue
		fi
		ensure_parent "$dest"
		if [ -e "$dest" ] || [ -L "$dest" ]; then
			backup "$dest"
		fi
		run ln -s "$src" "$dest"
		if [ "$DRY_RUN" != 1 ]; then
			ok "~/$rel → $(tildify "$src")"
		fi
		linked=$((linked + 1))
	done < <(find "$DOTFILES/home" \( -type f -o -type l \) ! -name .DS_Store | sort)
	if [ "$linked" -eq 0 ]; then
		ok "every link is in place"
	fi

	local f leftover=""
	for f in $LEGACY_FILES; do
		if [ -e "$HOME/$f" ] && [ ! -L "$HOME/$f" ]; then
			leftover="$leftover ~/$f"
		fi
	done
	if [ -n "$leftover" ]; then
		info "Left over from the old bootstrap and no longer used; delete when you're ready:$leftover"
	fi
}
