# XFCE desktop environment: the NixOS session (XFCE, LightDM, X server) and
# the home-manager user configuration.
# https://wiki.nixos.org/wiki/Xfce
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
        config.custom.features.graphical.enable && config.custom.features.graphical.desktopManager == "xfce"
      )
      {
        custom.features.graphical.displayServer = "xserver";

        # LightDM is the only display manager here that still needs the X server.
        services.xserver = {
          enable = true;
          excludePackages = [ pkgs.xterm ];
          desktopManager.xfce.enable = true;
          displayManager.lightdm.enable = true;
        };

        environment.xfce.excludePackages = [ pkgs.parole ];

        # The X server has no per-user touchpad settings, so these mirror the
        # GNOME ones system-wide.
        services.libinput.touchpad = {
          naturalScrolling = true;
          accelSpeed = "0.3";
        };

        # The location of the night light in the home-manager configuration.
        services.geoclue2 = {
          enable = true;
          appConfig.gammastep = {
            isAllowed = true;
            isSystem = false;
          };
        };
      };

  flake.modules.homeManager.linux =
    {
      lib,
      config,
      ...
    }:
    lib.mkIf
      (
        config.custom.features.graphical.enable && config.custom.features.graphical.desktopManager == "xfce"
      )
      {
        gtk = {
          enable = true;
          colorScheme = "dark";
        };

        # XFCE has no night light of its own.
        services.gammastep = {
          enable = true;
          provider = "geoclue2";
          temperature.night = 3700;
        };

        # xfconf-query -c <channel> -p <property> -v to discover keys.
        xfconf.settings = {
          xsettings = {
            "Net/ThemeName" = "Adwaita";
            "Net/IconThemeName" = "Adwaita";
            "Net/EnableEventSounds" = false;
            "Net/EnableInputFeedbackSounds" = false;
            "Gtk/FontName" = with config.custom.font.ui; "${family} ${toString size}";
            "Gtk/MonospaceFontName" = "${config.custom.font.family} ${toString config.custom.font.size}";
          };

          xfwm4 = {
            "general/theme" = "Default";
            "general/title_font" = with config.custom.font.ui; "${family} Bold ${toString size}";
            # close, minimize (hide) and maximize left of the title
            "general/button_layout" = "CHM|";
          };

          thunar.default-view = "ThunarDetailsView";

          keyboards = with config.custom.user.keyboard.repeat; {
            "Default/KeyRepeat/Delay" = delay;
            "Default/KeyRepeat/Rate" = 1000 / interval;
          };

          # The macOS screenshot and close shortcuts, as on GNOME.
          xfce4-keyboard-shortcuts = {
            "commands/custom/<Primary>space" = "vicinae vicinae://toggle";
            "commands/custom/<Shift><Super>3" = "xfce4-screenshooter --fullscreen";
            "commands/custom/<Shift><Super>4" = "xfce4-screenshooter --region";
            "commands/custom/<Shift><Super>5" = "xfce4-screenshooter";
            "xfwm4/custom/<Super>q" = "close_window_key";
          };
        };
      };
}
