#!/usr/bin/env bash

# macos.sh: macOS settings for a new Mac. Run by `./bootstrap.sh macos`, or directly.
#
# The baseline is how Cory's current Mac is set up. Settings marked "New" were
# chosen for the new machine. Settings that weren't chosen are left commented
# out at the end of their section, ready to switch on.
#
# Needs an administrator password. Restarts Finder, the Dock and the menu bar at
# the end; a few settings need a logout or an app restart.

if [ "$(uname)" != "Darwin" ]; then
	echo "macos.sh only runs on macOS." >&2
	exit 1
fi

# Close System Settings, so it doesn't overwrite settings we're about to change
osascript -e 'tell application "System Settings" to quit' >/dev/null 2>&1

# Ask for the administrator password upfront
sudo -v

# Keep-alive: update existing `sudo` time stamp until `macos.sh` has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Safari and Mail keep their settings in sandbox containers, which Terminal can
# only write to with Full Disk Access. The TCC database is protected the same way.
has_full_disk_access() {
	head -c 1 "$HOME/Library/Application Support/com.apple.TCC/TCC.db" >/dev/null 2>&1
}

###############################################################################
# General UI/UX                                                               #
###############################################################################

# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Expand print panel by default
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Save to disk (not to iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Disable Resume system-wide
defaults write NSGlobalDomain NSQuitAlwaysKeepsWindows -bool false

# Automatically quit printer app once the print jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# Reveal IP address, hostname, OS version, etc. when clicking the clock
# in the login window
sudo defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName

# Restart automatically if the computer freezes (not every Mac supports this)
sudo systemsetup -setrestartfreeze on >/dev/null 2>&1

# Disable smart quotes as they’re annoying when typing code
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# Disable smart dashes as they’re annoying when typing code
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Keep Photos app from launching when connecting a camera-like device
defaults write com.apple.ImageCapture disableHotPlug -bool true

# Not chosen: disable automatic capitalization, double-space period, and autocorrect
#defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
#defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
#defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

###############################################################################
# Trackpad, mouse, keyboard, and input                                        #
###############################################################################

# Trackpad: enable tap to click for this user and for the login screen
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Trackpad: map bottom right corner to right-click
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
defaults -currentHost write NSGlobalDomain com.apple.trackpad.trackpadCornerClickBehavior -int 1
defaults -currentHost write NSGlobalDomain com.apple.trackpad.enableSecondaryClick -bool true

# Keyboard navigation (Tab through all controls) stays off
defaults write NSGlobalDomain AppleKeyboardUIMode -int 0

# New: the fastest key repeat System Settings offers (takes effect after logging out)
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# New: holding a key repeats it instead of showing the accent menu
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

###############################################################################
# Touch ID                                                                    #
###############################################################################

# New: use Touch ID for sudo. /etc/pam.d/sudo_local survives macOS updates.
if [ ! -e /etc/pam.d/sudo_local ]; then
	echo "Writing 'auth sufficient pam_tid.so' to /etc/pam.d/sudo_local (Touch ID for sudo)"
	echo "auth       sufficient     pam_tid.so" | sudo tee /etc/pam.d/sudo_local >/dev/null
elif ! grep -q '^[^#]*pam_tid\.so' /etc/pam.d/sudo_local; then
	echo "/etc/pam.d/sudo_local exists without pam_tid.so; leaving it alone. Add this line to use Touch ID for sudo:"
	echo "  auth       sufficient     pam_tid.so"
fi

###############################################################################
# Finder                                                                      #
###############################################################################

# Show icons for hard drives, servers, and removable media on the desktop
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

# Finder: show status bar
defaults write com.apple.finder ShowStatusBar -bool true

# Finder: show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Finder: allow text selection in Quick Look
defaults write com.apple.finder QLEnableTextSelection -bool true

# When performing a search, search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Enable spring loading for directories
defaults write NSGlobalDomain com.apple.springing.enabled -bool true

# Avoid creating .DS_Store files on network volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# New: and on USB volumes
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Arrange desktop icons by kind, and icons in other icon views by name. These
# keys only exist once Finder has created them, so on a brand-new Mac this can
# do nothing; run macos.sh again after using Finder for a bit.
/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:arrangeBy kind" ~/Library/Preferences/com.apple.finder.plist 2>/dev/null
/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:arrangeBy name" ~/Library/Preferences/com.apple.finder.plist 2>/dev/null
/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:arrangeBy name" ~/Library/Preferences/com.apple.finder.plist 2>/dev/null

# Group items by name when grouping is on
defaults write com.apple.finder FXArrangeGroupViewBy -string "Name"

# Use icon view in all Finder windows by default
# Four-letter codes for the other view modes: `Nlsv`, `clmv`, `glyv`
defaults write com.apple.finder FXPreferredViewStyle -string "icnv"

# Disable the warning before emptying the Trash
defaults write com.apple.finder WarnOnEmptyTrash -bool false

# Enable AirDrop over Ethernet
defaults write com.apple.NetworkBrowser BrowseAllInterfaces -bool true

# Expand the following File Info panes:
# “General”, “Open with”, and “Sharing & Permissions”
defaults write com.apple.finder FXInfoPanesExpanded -dict \
	General -bool true \
	OpenWith -bool true \
	Privileges -bool true

# Not chosen: show all filename extensions, folders first, full path in the
# window title, and the ~/Library folder
#defaults write NSGlobalDomain AppleShowAllExtensions -bool true
#defaults write com.apple.finder _FXSortFoldersFirst -bool true
#defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
#chflags nohidden ~/Library

###############################################################################
# Dock and hot corners                                                        #
###############################################################################

# Enable spring loading for all Dock items
defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true

# Show indicator lights for open applications in the Dock
defaults write com.apple.dock show-process-indicators -bool true

# Don’t group windows by application in Mission Control
# (i.e. use the old Exposé behavior instead)
defaults write com.apple.dock expose-group-by-app -bool false

# Don’t automatically rearrange Spaces based on most recent use
defaults write com.apple.dock mru-spaces -bool false

# Set the icon size of Dock items to 64 pixels
defaults write com.apple.dock tilesize -int 64
# Enable dock magnification
defaults write com.apple.dock magnification -bool true
# Remove the auto-hiding Dock delay
defaults write com.apple.dock autohide-delay -float 0

# Not chosen: hide recent apps in the Dock
#defaults write com.apple.dock show-recents -bool false

# Hot corners
# Possible values:
#  0: no-op
#  2: Mission Control
#  3: Show application windows
#  4: Desktop
#  5: Start screen saver
#  6: Disable screen saver
# 10: Put display to sleep
# 11: Launchpad
# 12: Notification Center
# 13: Lock Screen
# 14: Quick Note
# Top left screen corner → Screen Saver
defaults write com.apple.dock wvous-tl-corner -int 5
defaults write com.apple.dock wvous-tl-modifier -int 0
# Top right screen corner → Screen Saver
defaults write com.apple.dock wvous-tr-corner -int 5
defaults write com.apple.dock wvous-tr-modifier -int 0
# Bottom left screen corner → Mission Control
defaults write com.apple.dock wvous-bl-corner -int 2
defaults write com.apple.dock wvous-bl-modifier -int 0
# Bottom right screen corner → Desktop
defaults write com.apple.dock wvous-br-corner -int 4
defaults write com.apple.dock wvous-br-modifier -int 0

###############################################################################
# Screenshots                                                                 #
###############################################################################

# Not chosen: save screenshots to ~/Screenshots as PNG, without window shadows
#mkdir -p "${HOME}/Screenshots"
#defaults write com.apple.screencapture location -string "${HOME}/Screenshots"
#defaults write com.apple.screencapture type -string "png"
#defaults write com.apple.screencapture disable-shadow -bool true

###############################################################################
# Safari & WebKit, Mail                                                       #
###############################################################################

# Add a context menu item for showing the Web Inspector in web views
defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

if has_full_disk_access; then
	# Safari: show the full URL in the address bar (note: this still hides the scheme)
	defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true

	# Safari: prevent opening ‘safe’ files automatically after downloading
	defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

	# Safari: allow hitting the Backspace key to go to the previous page in history
	defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2BackspaceKeyNavigationEnabled -bool true

	# Safari: enable the Develop menu and the Web Inspector
	defaults write com.apple.Safari IncludeDevelopMenu -bool true
	defaults write com.apple.Safari IncludeDebugMenu -bool true
	defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
	defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true

	# Mail: copy email addresses as `foo@example.com` instead of `Foo Bar <foo@example.com>`
	defaults write com.apple.mail AddressesIncludeNameOnPasteboard -bool false

	# Mail: add the keyboard shortcut ⌘ + Enter to send an email
	defaults write com.apple.mail NSUserKeyEquivalents -dict-add "Send" -string "@\\U21a9"
else
	echo "Skipped Safari and Mail settings: Terminal needs Full Disk Access to change them."
	echo "  Grant it in System Settings → Privacy & Security → Full Disk Access, then run macos.sh again."
fi

###############################################################################
# Terminal                                                                    #
###############################################################################

# Only use UTF-8 in Terminal.app
defaults write com.apple.terminal StringEncodings -array 4

# Use the built-in “Clear Dark” profile for new windows and at startup
osascript -e 'tell application "Terminal" to set default settings to settings set "Clear Dark"' \
	-e 'tell application "Terminal" to set startup settings to settings set "Clear Dark"' >/dev/null 2>&1

# New: Secure Keyboard Entry, so other apps can't read what's typed in Terminal
defaults write com.apple.terminal SecureKeyboardEntry -bool true

###############################################################################
# Activity Monitor                                                            #
###############################################################################

# Keep the current Mac's setting: don't force the main window open at launch
defaults write com.apple.ActivityMonitor OpenMainWindow -bool false

# Visualize CPU usage in the Activity Monitor Dock icon
defaults write com.apple.ActivityMonitor IconType -int 5

# Show all processes in Activity Monitor
defaults write com.apple.ActivityMonitor ShowCategory -int 100

# Sort Activity Monitor results by CPU usage
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0

###############################################################################
# TextEdit, Time Machine, Xcode                                               #
###############################################################################

# New: TextEdit opens new documents as plain text, and reads and writes UTF-8
defaults write com.apple.TextEdit RichText -int 0
defaults write com.apple.TextEdit PlainTextEncoding -int 4
defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4

# New: don't offer every new disk for Time Machine backups
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# New: show how long each build took in Xcode's activity area
defaults write com.apple.dt.Xcode ShowBuildOperationDuration -bool true

###############################################################################
# Mac App Store and Software Update                                           #
###############################################################################

# Enable the WebKit Developer Tools in the Mac App Store
defaults write com.apple.appstore WebKitDeveloperExtras -bool true

# Enable Debug Menu in the Mac App Store
defaults write com.apple.appstore ShowDebugMenu -bool true

# Not chosen: check for software updates daily and download them in the background
#defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
#defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1
#defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1

###############################################################################
# Google Chrome                                                               #
###############################################################################

# Allow installing user scripts via GitHub Gist
defaults write com.google.Chrome ExtensionInstallSources -array "https://gist.githubusercontent.com/"

# Use the system-native print preview dialog
defaults write com.google.Chrome DisablePrintPreview -bool true

# Expand the print dialog by default
defaults write com.google.Chrome PMPrintingExpandedStateForPrint2 -bool true

###############################################################################
# Restart affected apps                                                       #
###############################################################################

for app in "Activity Monitor" "cfprefsd" "Dock" "Finder" "SystemUIServer"; do
	killall "${app}" > /dev/null 2>&1
done
echo "Done. Restart Terminal and Chrome for their settings, and log out for key repeat."
