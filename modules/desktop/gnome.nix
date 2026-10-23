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
        services = {
          displayManager.gdm.enable = true;
          desktopManager.gnome.enable = true;
        };

        environment.sessionVariables = {
          NIXOS_OZONE_WL = "1";
          # Scales every built-in shell animation, which has no dconf key of its
          # own, to the macOS expose-animation-duration of 0.2 in
          # modules/core/settings.nix. Read once by js/ui/environment.js into
          # St.Settings.slow_down_factor, so it needs a re-login to take effect.
          GNOME_SHELL_SLOWDOWN_FACTOR = "0.2";
        };

        environment.gnome.excludePackages = with pkgs; [ gnome-tour ];

        environment.systemPackages = with pkgs; [ gnome-tweaks ];
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

      # The Vicinae companion extension exposes clipboard/window-management APIs
      # over D-Bus to the launcher, which every graphical host runs.
      extensions = with pkgs.gnomeExtensions; [
        blur-my-shell
        dash-to-dock
        rounded-window-corners-reborn
        vicinae
      ];

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
        home.packages = extensions;

        gtk = {
          enable = true;
          cursorTheme.name = "Adwaita";
          iconTheme.name = "Adwaita";
          colorScheme = "dark";
        };

        # https://github.com/gvolpe/dconf2nix (dconf watch / to discover keys)
        dconf.settings = {
          "org/gnome/shell" = {
            disable-user-extensions = false;
            enabled-extensions = map (ext: ext.extensionUuid) extensions;
            favorite-apps = map (name: "${name}.desktop") favorites;
          };

          "org/gnome/desktop/interface" = {
            show-battery-percentage = true;
            enable-hot-corners = false;
            font-name = "Inter 11";
            document-font-name = "Inter 11";
            monospace-font-name = "${config.custom.font.family} ${toString config.custom.font.size}";
            titlebar-font = "Inter Bold 11";
            clock-format = "24h";
            clock-show-weekday = true;
            clock-show-date = true;
          };

          "org/gnome/desktop/wm/preferences" = {
            button-layout = "appmenu:minimize,maximize,close";
          };

          "org/gnome/nautilus/preferences" = {
            default-folder-viewer = "list-view";
          };

          "org/gnome/settings-daemon/plugins/color" = {
            night-light-enabled = true;
            night-light-schedule-automatic = true;
            night-light-temperature = gv.mkUint32 2000;
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
          "org/gnome/shell/extensions/dash-to-dock" = {
            multi-monitor = true;
            dock-position = "BOTTOM";
            dash-max-icon-size = 42;
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
