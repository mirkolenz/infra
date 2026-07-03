# XFCE desktop environment: the NixOS session (XFCE, LightDM, xfconf/dconf) and
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
    lib.mkIf (config.custom.features.graphical.enable && config.custom.features.graphical.desktopManager == "xfce") {
      services.xserver = {
        desktopManager.xfce.enable = true;
        displayManager.lightdm.enable = true;
      };

      # xfconf is required for the home-manager xfconf.settings below to apply;
      # dconf backs GTK application settings.
      programs.xfconf.enable = true;
      programs.dconf.enable = true;

      security.pam.services.lightdm.enableGnomeKeyring = true;

      environment.xfce.excludePackages = with pkgs.xfce; [ parole ];
    };

  flake.modules.homeManager.linux =
    {
      lib,
      config,
      ...
    }:
    lib.mkIf (config.custom.features.graphical.enable && config.custom.features.graphical.desktopManager == "xfce") {
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
      };
    };
}
