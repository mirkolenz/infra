# Children's machines: German keyboard, games, and a locked GNOME session
# without terminal, second browser or admin apps.
{
  flake.modules.nixos.children =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      # by desktop entry
      games = {
        "org.kde.gcompris" = pkgs.gcompris;
        tuxpaint = pkgs.tuxpaint;
        # tuxtype ships no desktop entry
        tuxtype = pkgs.makeDesktopItem {
          name = "tuxtype";
          desktopName = "Tux Typing";
          exec = lib.getExe pkgs.tuxtype;
          icon = "${pkgs.tuxtype}/share/tuxtype/images/icons/tuxtype.svg";
          categories = [
            "Education"
            "Game"
          ];
        };
      };

      # Only the primary user keeps these, since the children may only run system packages.
      # Maps and Weather would be offline for them.
      primaryApps = with pkgs; [
        gnome-console
        epiphany
        gnome-control-center
        gnome-disk-utility
        baobab
        gnome-logs
        gnome-system-monitor
        gnome-connections
        seahorse
        gnome-color-manager
        gnome-maps
        gnome-weather
      ];
    in
    {
      # pam_apparmor only confines GDM sessions
      custom.features.graphical.desktopManager = "gnome";

      services.xserver.xkb.layout = "de";

      environment.gnome.excludePackages = primaryApps;
      users.users.${config.custom.user.login}.packages = primaryApps;

      # existing accounts would face the setup wizard
      services.gnome.gnome-initial-setup.enable = false;

      # media and folder sharing to the network
      services.gnome.rygel.enable = false;
      services.gnome.gnome-user-share.enable = false;

      environment.systemPackages = lib.attrValues games ++ [ pkgs.gnomeExtensions.dash-to-dock ];

      custom.children = {
        # downloads voices and music on demand
        online = [ "${pkgs.gcompris}/bin/{,.}gcompris-qt*" ];
        # sandboxes the thumbnailers and image loaders
        sandboxed = [ (lib.getExe pkgs.bubblewrap) ];
        # part of GNOME Shell
        denied = [ "${pkgs.gnome-shell}/bin/{,.}gnome-extensions-app*" ];
        hidden = [
          "org.gnome.Extensions"
          "org.freedesktop.IBus.Setup"
          # opens the web interface
          "cups"
        ];
      };

      # dconf prefers /run/dconf/user/<uid> even over DCONF_PROFILE
      systemd.tmpfiles.settings.children = lib.genAttrs' config.users.groups.children.members (
        name:
        lib.nameValuePair "/run/dconf/user/${toString config.users.users.${name}.uid}" {
          "L+".argument = "/etc/dconf/profile/children";
        }
      );

      programs.dconf.profiles.children.databases = [
        {
          lockAll = true;
          settings = {
            "org/gnome/shell" = {
              enabled-extensions = [ pkgs.gnomeExtensions.dash-to-dock.extensionUuid ];
              disable-user-extensions = false;
              allow-extension-installation = false;
              # Looking Glass
              development-tools = false;
              favorite-apps = map (name: "${name}.desktop") (
                lib.attrNames config.custom.websites
                ++ lib.attrNames games
                ++ [
                  "org.gnome.Nautilus"
                  "org.gnome.TextEditor"
                ]
              );
            };
            "org/gnome/shell/extensions/dash-to-dock" = {
              dock-fixed = true;
              dash-max-icon-size = lib.gvariant.mkInt32 64;
            };
            # Alt+F2
            "org/gnome/desktop/lockdown".disable-command-line = true;
            # screen sharing
            "org/gnome/desktop/remote-desktop/rdp".enable = false;
            "org/gnome/desktop/remote-desktop/vnc".enable = false;
          };
        }
      ];
    };
}
