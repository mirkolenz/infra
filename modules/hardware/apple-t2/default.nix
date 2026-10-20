{
  flake.modules.nixos.apple-t2 =
    { lib, pkgs, ... }:
    {
      options.custom.apple-t2 = {
        model = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "MacBookPro16,1";
          description = ''
            The DMI product name, which upstream's installer selects the speaker
            DSP and kernel parameters by.
            Null builds a generic image without the speaker DSP.
          '';
        };

        user = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "alice";
          description = ''
            The account the macOS Touch ID fingers are bound to and the Touch
            Bar daemon gets its devices for, like the user running upstream's
            installer. Null leaves binding to a manual `fprintd-enroll`.
          '';
        };
      };

      config = {
        # wpa_supplicant 2.11 offloads the four-way handshake to the firmware,
        # which the Broadcom chips of T2 Macs fail.
        # https://wiki.t2linux.org/guides/wifi-bluetooth/
        networking.networkmanager.wifi.backend = "iwd";

        # The GUI apps style their figures with it, upstream bundles it.
        fonts.packages = [ pkgs.jetbrains-mono ];
      };
    };
}
