# Ordered list of apps pinned to the dock/panel, shared by every desktop
# environment so that all of them mirror the macOS dock defined by
# `system.defaults.dock.persistent-apps` in modules/core/settings.nix.
# Entries are desktop file ids without the `.desktop` suffix; each desktop
# environment applies its own formatting on top.
#
# `roles` supplies the environment's own counterparts of the macOS shell apps
# (Finder, Activity Monitor, System Settings); a role the environment does not
# ship is left out. Mail, Calendar and Contacts are deliberately not roles: the
# EDS-integrated Stamp covers them on every desktop. Dock entries are skipped
# entirely when they have no Linux counterpart (App Store, Music, DEVONthink,
# ChatGPT, Claude, Messages, WhatsApp, OrbStack, Home Assistant), when
# the counterpart is not installed (zoom.us, dropped along with zoom-us in
# modules/core/home-linux.nix), or when the app is installed but not worth a
# permanent slot (Microsoft Teams, still available via teams-for-linux).
lib: roles:
lib.filter (app: app != null) [
  (roles.files or null) # Finder
  "obsidian"
  "firefox"
  # Chrome also ships com.google.Chrome.desktop for the portal app id,
  # but that one is NoDisplay=true and therefore invisible to every launcher.
  "google-chrome"
  "com.onepassword.OnePassword"
  "org.tabos.stamp" # Mail, Calendar, Contacts
  "todoist"
  "dev.zed.Zed"
  "com.mitchellh.ghostty"
  "zotero"
  "Stirling PDF" # PDF Expert; the desktop file name really does have a space
  "writer" # Microsoft Word
  "calc" # Microsoft Excel
  "impress" # Microsoft PowerPoint
  (roles.monitor or null) # Activity Monitor
  (roles.settings or null) # System Settings
]
