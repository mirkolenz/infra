# Downloads a macOS recovery image at build time, for machines whose own macOS
# install is gone. The blobs land in the store, so this needs `allowUnfree`.
# Stays inline rather than moving to pkgs/by-name: `vmTools.runInLinuxVM` yields
# something with `overrideDerivation` but no `overrideAttrs`, which the by-name
# update-script guard needs.
# https://wiki.t2linux.org/guides/wifi-bluetooth/ (method 5)
{
  flake.modules.nixos.apple-t2 =
    {
      config,
      inputs,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.custom.apple-t2.firmware;

      # https://github.com/kholia/OSX-KVM/blob/4c378a4b5e0b219783683012bec680325eb40719/fetch-macOS-v2.py#L547
      fetchmacos =
        pkgs.callPackage "${inputs.nixos-hardware}/apple/t2/pkgs/brcm-firmware/fetchmacos.nix"
          { };

      firmware = pkgs.callPackage "${inputs.nixos-hardware}/apple/t2/pkgs/brcm-firmware" {
        # Only selects a `boards` entry, and is replaced below along with it.
        version = "sonoma";
      };

      version = "tahoe";

      # Name and version are computed before the override applies.
      patchedFirmware = firmware.overrideDerivation (_old: {
        inherit version;
        name = "brcm-firmware-${version}";
        src = fetchmacos {
          name = version;
          boardId = "Mac-CFF7D910A743CAAF";
          mlb = "00000000000000000";
          osType = "default";
          hash = "sha256-l3PIhInQJeSmYIaxObgFDvZN40u2GgkPrqYaginTCvs=";
        };
      });
    in
    {
      hardware.firmware = lib.mkIf (cfg.enable && cfg.source == "recovery") [ patchedFirmware ];
    };
}
