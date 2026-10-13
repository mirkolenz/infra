# XFCE desktop environment: the NixOS session (XFCE, LightDM, X server) and
# the home-manager user configuration (appearance and fonts via xfconf).
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
        # LightDM is the only display manager here that still needs the X server.
        services.xserver = {
          enable = true;
          excludePackages = [ pkgs.xterm ];
          desktopManager.xfce.enable = true;
          displayManager.lightdm.enable = true;
        };

        environment.xfce.excludePackages = [ pkgs.parole ];
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
        # xfconf-query -c <channel> -p <property> -v to discover keys.
        xfconf.settings = {
          xsettings = {
            "Net/ThemeName" = "Adwaita-dark";
            "Net/IconThemeName" = "Adwaita";
            "Gtk/FontName" = "Inter 11";
            "Gtk/MonospaceFontName" = "JetBrains Mono 11";
          };

          xfwm4 = {
            "general/theme" = "Default";
            "general/title_font" = "Inter Bold 11";
          };

          xfce4-keyboard-shortcuts = {
            "commands/custom/<Primary>space" = "vicinae vicinae://toggle";
          };
        };
      };
}
