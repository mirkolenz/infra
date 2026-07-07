# KDE Plasma 6 desktop environment: the NixOS session (SDDM on Wayland, Plasma 6,
# KWallet) and the home-manager user configuration via plasma-manager (Breeze Dark
# appearance, fonts, night light, and a bottom panel with pinned favorites).
# https://github.com/nix-community/plasma-manager
{
  flake.modules.nixos.base =
    {
      lib,
      config,
      ...
    }:
    lib.mkIf
      (
        config.custom.features.graphical.enable
        && config.custom.features.graphical.desktopManager == "plasma"
      )
      {
        services = {
          desktopManager.plasma6.enable = true;
          displayManager.sddm = {
            enable = true;
            wayland.enable = true;
          };
        };

        # Auto-unlock the KDE wallet on login, mirroring the gnome-keyring wiring
        # of the other desktop environments.
        security.pam.services.sddm.kwallet.enable = true;

        environment.sessionVariables.NIXOS_OZONE_WL = "1";
      };

  flake.modules.homeManager.linux =
    {
      lib,
      config,
      ...
    }:
    lib.mkIf
      (
        config.custom.features.graphical.enable
        && config.custom.features.graphical.desktopManager == "plasma"
      )
      {
        # rc2nix (nix run github:nix-community/plasma-manager) dumps the current
        # Plasma settings as plasma-manager options to discover keys.
        programs.plasma = {
          enable = true;

          hotkeys.commands."toggle-vicinae" = {
            name = "Toggle Vicinae";
            key = "Ctrl+Space";
            command = "vicinae vicinae://toggle";
          };

          workspace = {
            clickItemTo = "select";
            lookAndFeel = "org.kde.breezedark.desktop";
            colorScheme = "BreezeDark";
            iconTheme = "breeze-dark";
            cursor.theme = "breeze_cursors";
          };

          fonts = {
            general = {
              family = "Inter";
              pointSize = 11;
            };
            fixedWidth = {
              family = "JetBrains Mono";
              pointSize = 11;
            };
          };

          kwin.nightLight = {
            enable = true;
            mode = "automatic";
            temperature.night = 2000;
          };

          panels = [
            {
              location = "bottom";
              floating = true;
              widgets = [
                "org.kde.plasma.kickoff"
                {
                  iconTasks.launchers = [
                    "applications:org.kde.dolphin.desktop"
                    "applications:vivaldi-stable.desktop"
                    "applications:1password.desktop"
                    "applications:obsidian.desktop"
                    "applications:dev.zed.Zed.desktop"
                    "applications:com.mitchellh.ghostty.desktop"
                    "applications:zotero.desktop"
                    "applications:Zoom.desktop"
                    "applications:systemsettings.desktop"
                  ];
                }
                "org.kde.plasma.marginsseparator"
                "org.kde.plasma.systemtray"
                "org.kde.plasma.digitalclock"
              ];
            }
          ];
        };
      };
}
