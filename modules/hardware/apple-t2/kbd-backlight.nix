# The keyboard backlight idle timeout, which upstream installs on every T2
# MacBook. See `pkgs/by-name/kait2en/kbd-backlight.nix`.
{
  flake.modules.nixos.apple-t2 =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.custom.apple-t2.kbd-backlight.enable =
        lib.mkEnableOption "the Apple T2 keyboard backlight idle timeout";

      config = lib.mkIf config.custom.apple-t2.kbd-backlight.enable {
        services.upower.enable = true;
        systemd.packages = [ pkgs.kait2en.kbd-backlight ];
        systemd.services.t2-kbd-backlight.wantedBy = [ "multi-user.target" ];
      };
    };
}
