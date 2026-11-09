# i915 with upstream's patches for PSR on Apple panels and the gmux brightness
# restore of dual GPU MacBook Pros, partly in drm_display_helper.
# https://github.com/kaiT2en/KaiT2en-Fedora/blob/main/scripts/fedora/install-i915.sh
{
  lib,
  kait2en,
}:
kait2en.mkPatchedDrivers {
  pname = "kait2en-i915";

  version = "0.1.13-unstable-2026-11-08";

  src = kait2en.fetchSource {
    rev = "8de95468f08c6db37924bcb8f9adc12c769add71";
    hash = "sha256-WWaldPR7m0QXXU9xTEzMIz2i5eEM+5oFY0UhKBgYl5s=";
    root = "patches/runtime/i915";
    # Only tracked, so the check flags a change to what is built.
    paths = [ "scripts/fedora/install-i915.sh" ];
  };

  drivers = [
    "drivers/gpu/drm/display"
    "drivers/gpu/drm/i915"
  ];
  # i915 reaches outside its directory only for the IPS header.
  sources = [ "drivers/platform/x86/intel_ips.h" ];

  # Like upstream, the other modules of both directories stay in-tree.
  makeFlags = [
    "CONFIG_DRM_DISPLAY_DP_AUX_BUS="
    "CONFIG_DRM_I915_GVT_KVMGT="
  ];

  meta = {
    description = "Intel graphics driver with Apple panel PSR and gmux brightness fixes for Apple T2 Macs";
    # i915 and the DRM helpers are MIT, the kernel they link into GPL-2.0-only,
    # and the patches follow the rest of upstream.
    license = with lib.licenses; [
      mit
      gpl2Only
      gpl3Plus
    ];
  };
}
