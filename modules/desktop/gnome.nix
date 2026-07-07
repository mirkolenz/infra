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
          gnome.core-apps.enable = true;
        };

        programs.dconf.enable = true;

        environment.sessionVariables.NIXOS_OZONE_WL = "1";

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

      # The Vicinae companion extension exposes clipboard/window-management APIs
      # over D-Bus and is only useful when the Vicinae launcher itself is running.
      extensions =
        (with pkgs.gnomeExtensions; [
          blur-my-shell
          dash-to-dock
          rounded-window-corners-reborn
        ])
        ++ lib.optional config.programs.vicinae.enable pkgs.gnomeExtensions.vicinae;

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
          theme.name = "Adwaita-dark";
        };

        # https://github.com/gvolpe/dconf2nix (dconf watch / to discover keys)
        dconf.settings = {
          "org/gnome/shell" = {
            disable-user-extensions = false;
            enabled-extensions = map (ext: ext.extensionUuid) extensions;
            favorite-apps = map (name: "${name}.desktop") [
              "org.gnome.Nautilus"
              "vivaldi-stable"
              "1password"
              "obsidian"
              "dev.zed.Zed"
              "com.mitchellh.ghostty"
              "zotero"
              "Zoom"
              "org.gnome.Settings"
            ];
          };

          "org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
            show-battery-percentage = true;
            enable-hot-corners = false;
            font-name = "Inter 11";
            document-font-name = "Inter 11";
            monospace-font-name = "JetBrains Mono 11";
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

          "org/gnome/mutter" = {
            experimental-features = [
              "scale-monitor-framebuffer"
              "xwayland-native-scaling"
            ];
          };

          "org/gnome/shell/extensions/dash-to-dock" = {
            multi-monitor = true;
            dock-position = "BOTTOM";
            dash-max-icon-size = 42;
            intellihide = false;
            disable-overview-on-startup = true;
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
