# Switches off GNOME's Night Light, automatic brightness and idle dimming while it runs.
{
  flake.modules.nixos.apple-t2 =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      package = pkgs.kait2en.truetone;
    in
    {
      options.custom.apple-t2.truetone.enable =
        lib.mkEnableOption "the Apple T2 True Tone, evening mode and automatic brightness on GNOME";

      config = lib.mkIf config.custom.apple-t2.truetone.enable {
        # The app and the shell extension, which the daemon enables for each user.
        environment.systemPackages = [ package ];
        systemd.packages = [ package ];
        services.udev.packages = [ package ];
        # Upstream leaves it to the app, its features are toggled there too.
        systemd.user.services.t2-truetone.wantedBy = [ "graphical-session.target" ];
      };
    };
}
