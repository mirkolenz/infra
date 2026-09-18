# tiny-dfr finds the Touch Bar display and its backlight by the driver names of
# the in-tree modules KaiT2en replaces, so the new names go into its own rules
# rather than into a second copy beside them. `--replace-fail` catches a rename
# on either side, and the package's `udevCheckHook` parses the result.
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
        postInstall = old.postInstall + ''
          rules=$out/lib/udev/rules.d
          substituteInPlace $rules/99-touchbar-tiny-dfr.rules \
            --replace-fail 'DRIVERS=="adp|appletbdrm"' 'DRIVERS=="adp|appletbdrm|t2bdrm"' \
            --replace-fail 'KERNEL=="appletb_backlight", DRIVERS=="hid-appletb-bl"' \
              'KERNEL=="appletb_backlight|t2tb_backlight", DRIVERS=="hid-appletb-bl|t2touchbar_bl"'
          substituteInPlace $rules/99-touchbar-seat.rules \
            --replace-fail 'DRIVERS=="adp|appletbdrm"' 'DRIVERS=="adp|appletbdrm|t2bdrm"'
        '';
      });
    };
}
