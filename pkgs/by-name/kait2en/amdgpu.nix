# amdgpu with upstream's GMUX runtime PM patches, which let the dGPU sleep in
# D3cold while the iGPU drives the panel and wake for PRIME and external
# displays.
# https://github.com/kaiT2en/KaiT2en-Fedora/blob/main/scripts/fedora/install-gpu-runtime-pm.sh
{
  lib,
  kait2en,
}:
let
  installer = "${kait2en.modules.src}/scripts/fedora/install-gpu-runtime-pm.sh";
  driver = "drivers/gpu/drm/amd/amdgpu";

  # Upstream writes it from a heredoc in its installer, checked in `postPatch`.
  modprobeConfig = "softdep amdgpu pre: t2gmux";

  # Backported in a form the reverse dry run misses, checked in `postPatch`.
  mergedSince = {
    "0001-drm-amdgpu-reset-VI-ASIC-on-MacBookPro15-1.patch" = "7.2.10";
  };

  # How the installer guards a merged patch.
  cutoff = version: ''kernel_version_ge "$kver" ${lib.replaceStrings [ "." ] [ " " ] version}'';
in
kait2en.mkPatchedDrivers {
  pname = "kait2en-amdgpu";

  series = "gpu-runtime-pm";
  inherit mergedSince;

  # The patches touch nothing outside the AMD tree, but amdgpu includes a few
  # DRM core headers through relative paths, so take the whole DRM subtree.
  sources = [ "drivers/gpu/drm" ];
  drivers = [ driver ];

  postPatch = ''
    grep -qxF ${lib.escapeShellArg modprobeConfig} ${installer} ||
      { echo "the amdgpu softdep changed upstream, see .agents/skills/kait2en/SKILL.md" >&2; exit 1; }

    ${lib.concatMapAttrsStringSep "\n" (name: version: ''
      grep -A3 -F ${lib.escapeShellArg "${name})"} ${installer} |
        grep -qF ${lib.escapeShellArg (cutoff version)} ||
        { echo "the merged amdgpu patches changed upstream, see .agents/skills/kait2en/SKILL.md" >&2; exit 1; }
    '') mergedSince}

    # Resolved against the kernel tree in-tree, but against `M=` out of it.
    substituteInPlace ${driver}/amdgpu_trace.h --replace-fail \
      '#define TRACE_INCLUDE_PATH ../../drivers/gpu/drm/amd/amdgpu' \
      '#define TRACE_INCLUDE_PATH .'
  '';

  passthru = { inherit modprobeConfig; };

  meta = {
    description = "amdgpu with Apple GMUX runtime power management for Apple T2 Macs";
    # amdgpu itself is MIT, the kernel it links into GPL-2.0-only, and the
    # patches follow the rest of upstream.
    license = with lib.licenses; [
      mit
      gpl2Only
      gpl3Plus
    ];
  };
}
