# KDE Plasma 6 desktop environment: the NixOS session (SDDM on Wayland, Plasma 6,
# KWallet) and the home-manager user configuration via plasma-manager.
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
        custom.features.graphical.displayServer = "wayland";

        services = {
          desktopManager.plasma6.enable = true;
          displayManager.sddm = {
            enable = true;
            wayland.enable = true;
          };
        };

        environment.sessionVariables.NIXOS_OZONE_WL = "1";
      };

  flake.modules.homeManager.linux =
    {
      lib,
      config,
      ...
    }:
    let
      favorites = import ./_favorites.nix lib {
        files = "org.kde.dolphin";
        monitor = "org.kde.plasma-systemmonitor";
        settings = "systemsettings";
      };
    in
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

          # The macOS screenshot shortcuts next to the Spectacle defaults.
          spectacle.shortcuts = {
            captureEntireDesktop = [
              "Shift+Print"
              "Meta+Shift+3"
            ];
            captureRectangularRegion = [
              "Meta+Shift+Print"
              "Meta+Shift+4"
            ];
            launch = [
              "Print"
              "Meta+Shift+5"
            ];
          };

          # Meta+Q closes the window as on macOS instead of switching activities.
          shortcuts = {
            kwin."Window Close" = [
              "Alt+F4"
              "Meta+Q"
            ];
            plasmashell."manage activities" = [ ];
          };

          kwin.titlebarButtons = {
            left = [
              "close"
              "minimize"
              "maximize"
            ];
            right = [ ];
          };

          configFile = {
            # The slow-down factor of the macOS expose-animation-duration in
            # modules/core/settings.nix, as on GNOME.
            kdeglobals.KDE.AnimationDurationFactor = 0.2;
            # 9 disables the overview of the top left hot corner.
            kwinrc.Effect-overview.BorderActivate = 9;
          };

          workspace = {
            clickItemTo = "select";
            lookAndFeel = "org.kde.breezedark.desktop";
            colorScheme = "BreezeDark";
            iconTheme = "breeze-dark";
            cursor.theme = "breeze_cursors";
            wallpaperPlainColor = "0,0,0";
          };

          input.keyboard = with config.custom.user.keyboard.repeat; {
            repeatDelay = delay;
            repeatRate = 1000.0 / interval;
          };

          kscreenlocker.appearance.wallpaperPlainColor = "0,0,0";

          fonts = {
            general = with config.custom.font.ui; {
              inherit family;
              pointSize = size;
            };
            fixedWidth = {
              family = config.custom.font.family;
              pointSize = config.custom.font.size;
            };
            windowTitle = with config.custom.font.ui; {
              inherit family;
              pointSize = size;
              weight = "bold";
            };
          };

          kwin.nightLight = {
            enable = true;
            mode = "automatic";
            temperature.night = 3700;
          };

          # A menu bar with the global menu, the tray and the clock on top, which
          # also places the notifications at the top right, and a dock at the
          # bottom that hides until the pointer reaches the edge, as on GNOME.
          panels = [
            {
              location = "top";
              height = 28;
              widgets = [
                "org.kde.plasma.kickoff"
                { appMenu = { }; }
                { panelSpacer = { }; }
                { systemTray.items.configs.battery.showPercentage = true; }
                {
                  digitalClock = {
                    date = {
                      format.custom = "ddd d MMM";
                      position = "besideTime";
                    };
                    time = {
                      format = "24h";
                      showSeconds = "always";
                    };
                  };
                }
              ];
            }
            {
              location = "bottom";
              height = 56;
              lengthMode = "fit";
              hiding = "autohide";
              floating = true;
              widgets = [
                {
                  iconTasks = {
                    launchers = map (name: "applications:${name}.desktop") favorites;
                    behavior.grouping.clickAction = "showPresentWindowsEffect";
                  };
                }
              ];
            }
          ];
        };
      };
}
