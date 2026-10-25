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
      # All of them come in German, the app grid lists them.
      apps = with pkgs; [
        gcompris
        tuxpaint
        kdePackages.klettres
        kdePackages.ktuberling
        kdePackages.khangman
        kdePackages.kanagram
        # German word lists of khangman and kanagram
        kdePackages.kdeedu-data
        kdePackages.blinken
        kdePackages.ktouch
        kdePackages.kgeography
        kdePackages.kturtle
        stellarium
        kdePackages.palapeli
        kdePackages.knavalbattle
        kdePackages.kapman
        kdePackages.kbreakout
        kdePackages.picmi
        kdePackages.kshisen
        kdePackages.katomic
        kdePackages.knetwalk
        kdePackages.kfourinline
        kdePackages.kiriki
        kdePackages.kolf
        kdePackages.bomber
        kdePackages.granatier
        kdePackages.kbounce
        kdePackages.kgoldrunner
        kdePackages.skladnik
        kdePackages.krecorder
        gnome-2048
        iagno
        gnome-nibbles
        quadrapassel
        lightsoff
        swell-foop
        gnome-chess
        # the opponent of gnome-chess
        gnuchess
        gnome-sudoku
        gnome-mines
        gnome-tetravex
        aisleriot
        supertux
        supertuxkart
        neverball
        pingus
        # ignores the locale, its config picks the language
        (blobby.overrideAttrs (prevAttrs: {
          postInstall = prevAttrs.postInstall + ''
            substituteInPlace $out/share/blobby/config.xml \
              --replace-fail 'name="language" value="en"' 'name="language" value="de"'
          '';
        }))
      ];

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

      environment.systemPackages = apps ++ [ pkgs.gnomeExtensions.dash-to-dock ];

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
      systemd.tmpfiles.settings.children = lib.mapAttrs' (
        _: user:
        lib.nameValuePair "/run/dconf/user/${toString user.uid}" {
          "L+".argument = "/etc/dconf/profile/children";
        }
      ) config.custom.children.users;

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
              # everything else lives in the app grid behind the dock's apps button
              favorite-apps = [
                "org.gnome.Nautilus.desktop"
                "org.gnome.TextEditor.desktop"
              ];
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
