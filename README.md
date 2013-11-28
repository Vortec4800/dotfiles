# Dotfiles machine configuration script

Before starting, make sure the latest version of Xcode is installed and run at least once (to install command-line tools) from the Mac App Store.

## Setup Git Keys

This is only required for a brand new machine, and is used to authenticate your computer with your GitHub account.

Create the key in the default directory:

```bash
ssh-keygen -t rsa -C "Computer Name"
```

When it asks for a password, press enter for no password.

Copy the key to the clipboard:

```bash
pbcopy < ~/.ssh/id_rsa.pub
```

Then go to Account Settings in GitHub and add this key to your account.

Full instructions for the above steps can be referenced from https://help.github.com/articles/generating-ssh-keys.

## Installation

```bash
git clone git@github.com:Vortec4800/dotfiles.git && cd dotfiles && ./bootstrap.sh
```

To update, `cd` into your local `dotfiles` repository and then:

```bash
./bootstrap.sh
```

This will automatically pull any changes and update your machine.

# Descriptions

## Aliases

The following commands are shortcuts available now:

### Directory Navigation

`..` - Parent directory

`...` - Up 2 directories

`~` - Switch to home directory

`d` - Switch to ~/Dropbox

### Directory Listing

`la` - List all files (including hidden) in long format

`lsd` - List only directories

### Network

`ip` - Get current public IP address

`localip` - Get current LAN IP

### Program Shortcuts

`g` - git

`e` - emacs

## Other Features

### General OS X
* Default to expanded save dialog
* Default to expanded print dialog
* Disable "Reopen windows when logging back in" when restarting computer by default
* Automatically quit Print Center app when printing is complete
* Copy email addresses intelligently as `foo@example.com` instead of `Foo Bar <foo@example.com>` in Mail.app
* Enable full keyboard access to system dialogs

### Finder
* Show icons for hard drives, servers, and removable media on the desktop
* Show status bar at bottom of Finder
* Search current folder by default
* Diable creating .DS_Store files on network volumes
* Enable snap-to-grid for icons on the desktop and in other icon views
* Enable AirDrop on all interfaces (Ethernet)
* Make Dock icons of hidden applications translucent

### Safari
* Enable Safari’s debug menu
* Allow hitting the Backspace key to go to the previous page in history

### Path
* Add Android Studio tools to path
* Git shortcut aliases
* Bash prompt with Git info in-line
* Configure git name/email
