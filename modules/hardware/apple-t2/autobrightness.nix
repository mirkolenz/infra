# Automatic brightness on GNOME, which switches off GNOME's own and idle dimming
# while it runs. See `pkgs/by-name/kait2en/autobrightness.nix`.
{
  flake.modules.nixos.apple-t2 =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      package = pkgs.kait2en.autobrightness;
    in
    {
      options.custom.apple-t2.autobrightness.enable =
        lib.mkEnableOption "the Apple T2 automatic display brightness on GNOME";

      config = lib.mkIf config.custom.apple-t2.autobrightness.enable {
        # The shell extension, which the daemon enables for each user.
        environment.systemPackages = [ package ];
        systemd.packages = [ package ];
        systemd.user.services.kait2en-t2-autobrightness = {
          wantedBy = [ "graphical-session.target" ];
          # It switches GNOME's settings through `gsettings`.
          path = [ pkgs.glib ];
        };
      };
    };
}
