# tiny-dfr finds the Touch Bar display and its backlight by the driver names of
# the in-tree modules KaiT2en replaces, so the new names go into its own rules
# rather than into a second copy beside them. `--replace-fail` catches a rename
# on either side, and the package's `udevCheckHook` parses the result.
# The backlight is looked up twice over: udev only routes the device unit, while
# the daemon itself scans `/sys/class/backlight` against a list built into the
# binary, so `t2tb_backlight` has to be added there as well or it panics.
# `gmux_backlight`, which `t2gmux` registers, is already in the display list.
# The same rules are also where the daemon survives a suspend. It is `BindsTo=`
# its display and backlight device, so systemd stops it the moment either one
# goes, which S3 does: the Touch Bar hangs off the T2's virtual USB bus and is
# torn down with it. Upstream carries `SYSTEMD_WANTS` only on the touch input
# device, a third device it is not bound to, so coming back up rests on that one
# being re-added after the other two went, which on resume it is not, and the
# daemon stays stopped having exited cleanly. Wanting it from the two devices it
# is bound to closes the pattern, and whichever settles last pulls it up.
{
  flake.modules.nixos.apple-t2 =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    lib.mkIf config.hardware.apple.touchBar.enable {
      hardware.apple.touchBar.package = pkgs.tiny-dfr.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace src/backlight.rs \
            --replace-fail '"appletb_backlight"]' '"appletb_backlight", "t2tb_backlight"]'
        '';

        postInstall = old.postInstall + ''
          rules=$out/lib/udev/rules.d
          substituteInPlace $rules/99-touchbar-tiny-dfr.rules \
            --replace-fail 'DRIVERS=="adp|appletbdrm"' 'DRIVERS=="adp|appletbdrm|t2bdrm"' \
            --replace-fail 'KERNEL=="appletb_backlight", DRIVERS=="hid-appletb-bl"' \
              'KERNEL=="appletb_backlight|t2tb_backlight", DRIVERS=="hid-appletb-bl|t2touchbar_bl"' \
            --replace-fail 'ENV{SYSTEMD_ALIAS}="/dev/tiny_dfr_display"' \
              'ENV{SYSTEMD_ALIAS}="/dev/tiny_dfr_display", ENV{SYSTEMD_WANTS}="tiny-dfr.service"' \
            --replace-fail 'ENV{SYSTEMD_ALIAS}="/dev/tiny_dfr_backlight"' \
              'ENV{SYSTEMD_ALIAS}="/dev/tiny_dfr_backlight", ENV{SYSTEMD_WANTS}="tiny-dfr.service"'
          substituteInPlace $rules/99-touchbar-seat.rules \
            --replace-fail 'DRIVERS=="adp|appletbdrm"' 'DRIVERS=="adp|appletbdrm|t2bdrm"'
        '';
      });
    };
}
