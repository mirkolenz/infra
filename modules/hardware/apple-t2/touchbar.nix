# tiny-dfr finds the Touch Bar display and its backlight by the driver names of
# the in-tree modules KaiT2en replaces, so those two rules are restated here.
# Its remaining rules match on hardware names and still apply.
# From tiny-dfr, (C) The Asahi Linux Contributors, Apache-2.0 OR MIT.
# https://github.com/AsahiLinux/tiny-dfr/blob/master/etc/udev/rules.d/99-touchbar-tiny-dfr.rules
{
  flake.modules.nixos.apple-t2 =
    { config, lib, ... }:
    lib.mkIf config.hardware.apple.touchBar.enable {
      services.udev.extraRules = ''
        SUBSYSTEM=="drm", KERNEL=="card[0-9]*", DRIVERS=="t2bdrm", TAG+="systemd", ENV{SYSTEMD_ALIAS}="/dev/tiny_dfr_display", TAG-="master-of-seat", ENV{ID_SEAT}="seat-touchbar"
        SUBSYSTEM=="backlight", KERNEL=="t2tb_backlight", DRIVERS=="t2touchbar_bl", TAG+="systemd", ENV{SYSTEMD_ALIAS}="/dev/tiny_dfr_backlight"
      '';
    };
}
