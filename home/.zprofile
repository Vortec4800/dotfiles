# Login shells: put Homebrew on PATH. Everything else lives in ~/.zshrc and ~/.path.
if [[ -x /opt/homebrew/bin/brew ]]; then
	eval "$(/opt/homebrew/bin/brew shellenv)"
fi
