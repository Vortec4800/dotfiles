# oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="steeef"
COMPLETION_WAITING_DOTS="true"
# One completion cache, instead of a new ~/.zcompdump-<hostname> each time the hostname changes.
ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-$ZSH_VERSION"
[[ -d ${ZSH_COMPDUMP:h} ]] || mkdir -p "${ZSH_COMPDUMP:h}"

plugins=(
	git
	bbedit
	npm
	sudo
	macos
	dotenv
)

source "$ZSH/oh-my-zsh.sh"

# oh-my-zsh sets the history options; keep as many lines on disk as in memory.
SAVEHIST=$HISTSIZE

# Load the shell dotfiles:
# * ~/.path extends `$PATH`.
# * ~/.extra holds machine-local or private settings that don't belong in the repo.
for file in ~/.{path,exports,aliases,functions,extra}; do
	[[ -r "$file" && -f "$file" ]] && source "$file"
done
unset file

# Node versions (fnm). After ~/.path, so fnm's node comes before Homebrew's.
# --use-on-cd switches versions when entering a folder with .nvmrc or .node-version.
if (( $+commands[fnm] )); then
	eval "$(fnm env --use-on-cd --shell zsh)"
fi

# After a reboot the SSH agent is empty until the first ssh connection, and
# signed commits need the key. Load it from the Keychain if the agent has none.
if ! ssh-add -l >/dev/null 2>&1; then
	ssh-add --apple-load-keychain -q 2>/dev/null
fi
