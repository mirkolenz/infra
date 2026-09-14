# Kernel for Macs with an Apple T2 security chip, carrying the t2linux patch set
# on top of a mainline tree.
# https://github.com/t2linux/linux-t2-patches
# nix run .#t2-updater -- --branch main ./pkgs/by-name/linux-t2/kernel.json
#
# Shaped like a nixpkgs kernel file rather than an ordinary package: it swallows
# unknown arguments and folds them back into the override. `linuxPackagesFor`
# reaches in through `.override` with a function of the previous arguments, and
# callPackage answers that call by re-running this file, so anything the file
# contributes has to be recomputed here. Layering the patches on from the
# outside instead loses them the moment something overrides `kernelPatches`.
{
  lib,
  fetchurl, # fetchpatch would normalise the patches unnecessarily
  linux_7_2,
  ...
}@args:
let
  patchset = lib.importJSON ./kernel.json;

  t2Patches = map (
    { name, hash }:
    {
      inherit name;
      patch = fetchurl {
        inherit name hash;
        url = patchset.base_url + name;
      };
    }
  ) patchset.patches;
in
linux_7_2.override (
  removeAttrs args [ "linux_7_2" ]
  // {
    pname = "linux-t2";

    kernelPatches = t2Patches ++ (args.kernelPatches or [ ]);

    # Mirrors the upstream extra_config, which is not derivable from the patches:
    # most symbols here are mainline ones the patch set never mentions.
    # Check it for new entries whenever kernel.json is bumped.
    # https://github.com/t2linux/linux-t2-patches/blob/main/extra_config
    #
    # DRM_KUNIT_TEST is the one entry left out: upstream carries it to pull in
    # DRM_GEM_SHMEM_HELPER for the then out-of-tree appletbdrm, which selects
    # that itself since being upstreamed, and nixpkgs sets KUNIT = no anyway.
    structuredExtraConfig = with lib.kernel; {
      APFS_FS = module;
      APPLE_GMUX = module;
      BRCMFMAC = module;
      BT_BCM = module;
      BT_HCIBCM4377 = module;
      BT_HCIUART = module;
      BT_HCIUART_BCM = yes;
      DRM_APPLETBDRM = module;
      HID_APPLE = module;
      HID_APPLETB_BL = module;
      HID_APPLETB_KBD = module;
      HID_MAGICMOUSE = module;
      HID_SENSOR_ALS = module;
      I2C = yes;
      MEDIA_ANALOG_TV_SUPPORT = yes;
      MEDIA_CAMERA_SUPPORT = yes;
      MEDIA_DIGITAL_TV_SUPPORT = yes;
      MEDIA_PLATFORM_SUPPORT = yes;
      MEDIA_RADIO_SUPPORT = yes;
      MEDIA_SDR_SUPPORT = yes;
      MEDIA_SUPPORT = yes;
      MEDIA_TEST_SUPPORT = yes;
      SENSORS_APPLESMC = module;
      SND_PCM = module;
      STAGING = yes;
      T2BCE_AUDIO = module;
      T2BCE_AVE = module;
      T2BCE_CORE = module;
      T2BCE_DMA = module;
      T2BCE_VHCI = module;
    };

    argsOverride = {
      extraMeta = {
        description = "The Linux kernel (with patches from the T2 Linux project)";
        # A kernel build is far too expensive to run in CI.
        hydraPlatforms = [ ];
      };
    }
    // (args.argsOverride or { });
  }
)
