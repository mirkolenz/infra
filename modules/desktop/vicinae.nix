# Vicinae: a native, fast, extensible launcher (Raycast-like) available across
# every Linux desktop. Runs as a user systemd service that autostarts with the
# graphical session. https://docs.vicinae.com/nixos
{
  flake.modules.homeManager.linux =
    {
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.graphical.enable {
      programs.vicinae = {
        enable = true;

        systemd = {
          enable = true;
          autoStart = true;
        };

        settings = {
          theme = {
            dark.name = "vicinae-dark";
            light.name = "vicinae-light";
          };
          font.normal.family = "Inter";

          # Layer shell gives the nicest overlay on wlroots/KWin compositors but is
          # unsupported on GNOME (Mutter) and X11 (XFCE), where a plain floating
          # window is the robust fallback.
          launcher_window.layer_shell.enabled = lib.elem config.custom.features.graphical.desktopManager [
            "cosmic"
            "plasma"
          ];
        };
      };
    };
}
