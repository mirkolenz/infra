# Cosmic desktop environment: the NixOS session (greeter, scheduler, Wayland)
# and the home-manager user configuration (appearance, applets, cosmic apps).
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
        && config.custom.features.graphical.desktopManager == "cosmic"
      )
      {
        services = {
          desktopManager.cosmic.enable = true;
          displayManager.cosmic-greeter.enable = true;
          system76-scheduler.enable = true;
        };

        security.pam.services.greetd.enableGnomeKeyring = true;

        environment.sessionVariables.NIXOS_OZONE_WL = "1";
      };

  flake.modules.homeManager.linux =
    {
      lib,
      config,
      cosmicLib,
      ...
    }:
    lib.mkIf
      (
        config.custom.features.graphical.enable
        && config.custom.features.graphical.desktopManager == "cosmic"
      )
      {
        wayland.desktopManager.cosmic = {
          enable = true;
          appearance.theme.mode = "dark";
          # Written to configFile directly rather than via the higher-level
          # `shortcuts` option, whose action type builds a regex with a lazy
          # quantifier that Nix's POSIX regex engine rejects.
          configFile."com.system76.CosmicSettings.Shortcuts" = {
            version = 1;
            entries.custom = cosmicLib.cosmic.mkRON "map" [
              {
                key = {
                  modifiers = [ (cosmicLib.cosmic.mkRON "enum" "Ctrl") ];
                  key = "space";
                  description = cosmicLib.cosmic.mkRON "optional" "Toggle Vicinae";
                };
                value = cosmicLib.cosmic.mkRON "enum" {
                  variant = "Spawn";
                  value = [ "vicinae vicinae://toggle" ];
                };
              }
            ];
          };
          wallpapers = [
            {
              filter_by_theme = true;
              filter_method = cosmicLib.cosmic.mkRON "enum" "Lanczos";
              output = "all";
              rotation_frequency = 0;
              sampling_method = cosmicLib.cosmic.mkRON "enum" "Alphanumeric";
              scaling_mode = cosmicLib.cosmic.mkRON "enum" "Stretch";
              source = cosmicLib.cosmic.mkRON "enum" {
                variant = "Color";
                value = [
                  (cosmicLib.cosmic.mkRON "enum" {
                    variant = "Single";
                    value = [
                      (cosmicLib.cosmic.mkRON "tuple" [
                        0.0
                        0.0
                        0.0
                      ])
                    ];
                  })
                ];
              };
            }
          ];
          applets.app-list.settings = {
            enable_drag_source = true;
            favorites = [
              "com.system76.CosmicFiles"
              "vivaldi"
              "1password"
              "obsidian"
              "zed"
              "com.system76.CosmicEdit"
              "com.mitchellh.ghostty"
              "zotero"
              "Zoom"
              "com.system76.CosmicSettings"
            ];
            filter_top_levels = null;
          };
        };
        programs = {
          cosmic-applibrary = {
            enable = true;
            settings.groups = [ ];
          };
          cosmic-edit = {
            enable = true;
          };
          cosmic-files = {
            enable = true;
          };
          cosmic-player = {
            enable = true;
          };
          cosmic-store = {
            enable = false;
          };
          cosmic-term = {
            enable = false;
          };
          forecast = {
            enable = false;
          };
          tasks = {
            enable = false;
          };
        };
      };
}
