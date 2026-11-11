# Cosmic desktop environment: the NixOS session (greeter, scheduler, Wayland)
# and the home-manager user configuration.
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
        custom.features.graphical.displayServer = "wayland";

        services = {
          desktopManager.cosmic.enable = true;
          displayManager.cosmic-greeter.enable = true;
          system76-scheduler.enable = true;
        };

        environment.sessionVariables.NIXOS_OZONE_WL = "1";
      };

  flake.modules.homeManager.linux =
    {
      lib,
      config,
      pkgs,
      cosmicLib,
      ...
    }:
    let
      inherit (cosmicLib.cosmic) mkRON;

      favorites = import ./_favorites.nix lib {
        files = "com.system76.CosmicFiles";
        settings = "com.system76.CosmicSettings";
      };

      mkShortcut = modifiers: key: description: action: {
        key = {
          modifiers = map (mkRON "enum") modifiers;
          inherit key;
          description = mkRON "optional" description;
        };
        value = action;
      };

      # The interactive screenshot UI, which covers all three macOS shortcuts.
      screenshot = mkRON "enum" {
        variant = "System";
        value = [ (mkRON "enum" "Screenshot") ];
      };
    in
    lib.mkIf
      (
        config.custom.features.graphical.enable
        && config.custom.features.graphical.desktopManager == "cosmic"
      )
      {
        wayland.desktopManager.cosmic = {
          enable = true;
          appearance.theme.mode = "dark";
          # Replaces the whole keyboard config, so the layout is set here as well.
          compositor.xkb_config = with config.custom.user.keyboard; {
            inherit layout;
            options = mkRON "optional" (lib.concatStringsSep "," options);
            model = "pc104";
            rules = "";
            variant = "";
            repeat_delay = repeat.delay;
            repeat_rate = 1000 / repeat.interval;
          };
          configFile = {
            # Written to configFile directly rather than via the higher-level
            # `shortcuts` option, whose action type builds a regex with a lazy
            # quantifier that Nix's POSIX regex engine rejects.
            "com.system76.CosmicSettings.Shortcuts" = {
              version = 1;
              entries.custom = mkRON "map" (
                [
                  (mkShortcut [ "Ctrl" ] "space" "Toggle Vicinae" (
                    mkRON "enum" {
                      variant = "Spawn";
                      value = [ "vicinae vicinae://toggle" ];
                    }
                  ))
                ]
                ++ map (key: mkShortcut [ "Super" "Shift" ] key "Screenshot" screenshot) [
                  "3"
                  "4"
                  "5"
                ]
              );
            };
            # Reveals without delay and slides in 0.1s, mirroring the macOS dock as on GNOME.
            "com.system76.CosmicPanel.Dock" = {
              version = 1;
              entries = {
                autohide = mkRON "enum" "Always";
                autohide_behavior = {
                  wait_time = 0;
                  transition_time = 100;
                  handle_size = 4;
                  unhide_delay = 0;
                };
              };
            };
            "com.system76.CosmicNotifications" = {
              version = 1;
              entries.anchor = mkRON "enum" "TopRight";
            };
          };
          wallpapers = [
            {
              filter_by_theme = true;
              filter_method = mkRON "enum" "Lanczos";
              output = "all";
              rotation_frequency = 0;
              sampling_method = mkRON "enum" "Alphanumeric";
              scaling_mode = mkRON "enum" "Stretch";
              source = mkRON "enum" {
                variant = "Color";
                value = [
                  (mkRON "enum" {
                    variant = "Single";
                    value = [
                      (mkRON "tuple" [
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
          applets = {
            app-list.settings = {
              enable_drag_source = true;
              inherit favorites;
              filter_top_levels = null;
            };
            time.settings = {
              military_time = true;
              show_seconds = true;
              show_weekday = true;
            };
          };
        };
        programs = {
          # The default package is the renamed `cosmic-applibrary` alias, which warns.
          cosmic-applibrary = {
            enable = true;
            package = pkgs.cosmic-app-library;
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
