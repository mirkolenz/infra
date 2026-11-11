# GNOME desktop environment: the NixOS session (GDM, GNOME, keyring) and the
# home-manager user configuration (GTK theme, extensions, dconf settings).
{
  flake.modules.nixos.base =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    lib.mkIf
      (
        config.custom.features.graphical.enable
        && config.custom.features.graphical.desktopManager == "gnome"
      )
      {
        custom.features.graphical.displayServer = "wayland";

        services = {
          displayManager.gdm.enable = true;
          desktopManager.gnome.enable = true;
        };

        environment.sessionVariables.NIXOS_OZONE_WL = "1";

        environment.gnome.excludePackages = with pkgs; [ gnome-tour ];

        # Lets GNOME's automatic time zone set it through timedated.
        time.timeZone = null;
      };

  flake.modules.homeManager.linux =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      gv = lib.hm.gvariant;

      favorites = import ./_favorites.nix lib {
        files = "org.gnome.Nautilus";
        monitor = "org.gnome.SystemMonitor";
        settings = "org.gnome.Settings";
      };

      # solid black, also on the lock screen
      background = {
        picture-options = "none";
        color-shading-type = "solid";
        primary-color = "#000000";
      };

      # GNOME stores command shortcuts at indexed custom-keybinding subpaths that
      # must also be listed in `custom-keybindings`; this maps a friendlier attrset
      # of shortcuts (keyed by a slug) onto both the list and the per-shortcut keys.
      mediaKeys = "org/gnome/settings-daemon/plugins/media-keys";
      mkCustomKeybindings =
        shortcuts:
        {
          "${mediaKeys}".custom-keybindings = lib.mapAttrsToList (
            slug: _: "/${mediaKeys}/custom-keybindings/${slug}/"
          ) shortcuts;
        }
        // lib.mapAttrs' (
          slug: value: lib.nameValuePair "${mediaKeys}/custom-keybindings/${slug}" value
        ) shortcuts;
    in
    lib.mkIf
      (
        config.custom.features.graphical.enable
        && config.custom.features.graphical.desktopManager == "gnome"
      )
      {
        home.packages = [ pkgs.gnome-tweaks ];

        # GNOME's own inhibitor, which `--inhibit idle` extends to the display.
        programs.fish.shellAbbrs.caffeinate = "gnome-session-inhibit --inhibit suspend";

        programs.gnome-shell = {
          enable = true;
          # The Vicinae companion extension exposes clipboard/window-management APIs
          # over D-Bus to the launcher, which every graphical host runs.
          extensions = map (package: { inherit package; }) (
            with pkgs.gnomeExtensions;
            [
              appindicator
              blur-my-shell
              dash-to-dock
              desktop-icons-ng-ding
              just-perfection
              # TODO: uncomment once nixpkgs ships a release supporting GNOME 51,
              # which rounds the windows of apps that do not round their own corners.
              # rounded-window-corners-reborn
              tiling-assistant
              vicinae
            ]
          );
        };

        gtk = {
          enable = true;
          font = {
            inherit (config.custom.font.ui) size;
            name = config.custom.font.ui.family;
          };
          cursorTheme.name = "Adwaita";
          iconTheme.name = "Adwaita";
          colorScheme = "dark";
        };

        # https://github.com/gvolpe/dconf2nix (dconf watch / to discover keys)
        dconf.settings = {
          "org/gnome/shell".favorite-apps = map (name: "${name}.desktop") favorites;

          # font-name comes from gtk.font, which has no counterpart for the others
          "org/gnome/desktop/interface" = {
            show-battery-percentage = true;
            enable-hot-corners = false;
            document-font-name = with config.custom.font.ui; "${family} ${toString size}";
            monospace-font-name = "${config.custom.font.family} ${toString config.custom.font.size}";
            clock-format = "24h";
            clock-show-weekday = true;
            clock-show-seconds = true;
          };

          "org/gnome/desktop/sound".event-sounds = false;

          # A separate set of workspaces on each display, unlike the GNOME default.
          "org/gnome/mutter".workspaces-only-on-primary = false;

          # The macOS screenshot shortcuts next to the GNOME defaults, with the
          # interactive UI covering both the selection and the options of macOS.
          "org/gnome/shell/keybindings" = {
            screenshot = [
              "<Shift>Print"
              "<Shift><Super>3"
            ];
            show-screenshot-ui = [
              "Print"
              "<Shift><Super>4"
              "<Shift><Super>5"
            ];
          };

          "org/gnome/desktop/wm/keybindings".close = [
            "<Alt>F4"
            "<Super>q"
          ];

          # The macOS menu bar has the clock at the far right and no Activities
          # button, and its notifications appear at the top right.
          # Animation 3 is the slow-down factor of 0.2, matching the macOS
          # expose-animation-duration in modules/core/settings.nix.
          "org/gnome/shell/extensions/just-perfection" = {
            activities-button = false;
            clock-menu-position = 1;
            clock-menu-position-offset = 20;
            notification-banner-position = 2;
            window-demands-attention-focus = true;
            animation = 3;
            support-notifier-type = 0;
          };

          # GNOME ignores the system layout
          "org/gnome/desktop/input-sources" = {
            sources = [
              (gv.mkTuple [
                "xkb"
                config.custom.user.keyboard.layout
              ])
            ];
            xkb-options = config.custom.user.keyboard.options;
          };

          "org/gnome/desktop/peripherals/keyboard" = with config.custom.user.keyboard.repeat; {
            delay = gv.mkUint32 delay;
            repeat-interval = gv.mkUint32 interval;
          };

          "org/gnome/desktop/background" = background;
          "org/gnome/desktop/screensaver" = background;

          "org/gnome/desktop/wm/preferences".button-layout = "close,minimize,maximize:";

          # Replaces the edge tiling of GNOME with the halves, quarters and fill of
          # macOS, without gaps like EnableTiledWindowMargins = false. Tiled windows
          # stay independent instead of offering to fill the rest of the screen or
          # raising each other.
          "org/gnome/shell/extensions/tiling-assistant" = {
            enable-tiling-popup = false;
            enable-raise-tile-group = false;
          };

          # TODO: uncomment once nixpkgs ships blur-my-shell v77, which adds the
          # built-in Liquid Glass pipeline. The blur has to be dynamic, since a
          # static one only blurs the solid black wallpaper.
          # "org/gnome/shell/extensions/blur-my-shell/panel" = {
          #   pipeline = "pipeline_liquid_glass";
          #   static-blur = false;
          # };
          # "org/gnome/shell/extensions/blur-my-shell/dash-to-dock" = {
          #   pipeline = "pipeline_liquid_glass";
          #   static-blur = false;
          # };
          # "org/gnome/shell/extensions/blur-my-shell/popup".pipeline = "pipeline_liquid_glass";

          # Only the files in ~/Desktop as with the macOS CreateDesktop, without the
          # home folder and trash that macOS never shows there, and without drives
          # as with the Show*OnDesktop settings. New icons start top right.
          "org/gnome/shell/extensions/ding" = {
            show-home = false;
            show-trash = false;
            show-volumes = false;
            start-corner = "top-right";
          };

          "org/gnome/nautilus/preferences" = {
            default-folder-viewer = "list-view";
          };

          # Night light and the time zone follow the location from geoclue
          "org/gnome/system/location" = {
            enabled = true;
          };

          "org/gnome/desktop/datetime" = {
            automatic-timezone = true;
          };

          "org/gnome/settings-daemon/plugins/color" = {
            night-light-enabled = true;
            night-light-schedule-automatic = true;
            night-light-temperature = gv.mkUint32 3700;
          };

          "org/gnome/desktop/peripherals/touchpad" = {
            speed = 0.3;
            tap-to-click = true;
            natural-scroll = true;
          };

          # The delays and durations mirror the macOS dock settings in
          # modules/core/settings.nix: reveal the dock as soon as the pointer
          # reaches the edge (autohide-delay 0.0, plus no pressure barrier, which
          # has no macOS counterpart) and slide it in and out in 0.1s, the effect
          # of autohide-time-modifier 0.2 on the roughly 0.5s macOS animation.
          # The Super+number hotkeys would clash with the screenshot shortcuts.
          "org/gnome/shell/extensions/dash-to-dock" = {
            multi-monitor = true;
            click-action = "focus-or-appspread";
            running-indicator-style = "DOT";
            show-mounts = false;
            hot-keys = false;
            intellihide = false;
            disable-overview-on-startup = true;
            animation-time = 0.1;
            hide-delay = 0.0;
            show-delay = 0.0;
            require-pressure-to-show = false;
            pressure-threshold = 0.0;
          };
        }
        // mkCustomKeybindings {
          vicinae = {
            name = "Toggle Vicinae";
            command = "vicinae vicinae://toggle";
            binding = "<Control>space";
          };
        };
      };
}
