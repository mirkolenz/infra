# Wi-Fi and Bluetooth firmware for the Broadcom chip of T2 Macs. There is no
# free firmware and Apple does not allow redistribution, so it has to come out
# of a macOS image, either the installed one or a downloaded recovery image.
{
  flake.modules.nixos.apple-t2 =
    { lib, ... }:
    {
      options.custom.apple-t2.firmware = {
        enable = lib.mkEnableOption "the Broadcom Wi-Fi and Bluetooth firmware";

        source = lib.mkOption {
          type = lib.types.enum [
            "macos"
            "recovery"
          ];
          default = "macos";
          description = ''
            Where to take the firmware from. `macos` reads the install sharing
            the disk at runtime, `recovery` downloads an image from Apple at
            build time.
          '';
        };
      };
    };
}
