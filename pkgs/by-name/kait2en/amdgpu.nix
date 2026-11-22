# amdgpu with upstream's GMUX runtime PM patches, which let the dGPU sleep in
# D3cold while the iGPU drives the panel and wake for PRIME and external
# displays.
# https://github.com/kaiT2en/KaiT2en-Fedora/blob/main/scripts/fedora/install-gpu-runtime-pm.sh
{
  lib,
  kait2en,
  mesa,
}:
let
  installer = "scripts/fedora/install-gpu-runtime-pm.sh";
  driver = "drivers/gpu/drm/amd/amdgpu";

  # Upstream writes it from a heredoc in its installer, checked in `postPatch`.
  modprobeConfig = "softdep amdgpu pre: t2gmux";
in
kait2en.mkPatchedDrivers {
  pname = "kait2en-amdgpu";

  version = "0.1.16-unstable-2026-11-21";

  src = kait2en.fetchSource {
    rev = "fd46d003c2599fb28bbde6a90f99816d73b04e61";
    hash = "sha256-XhwG191Cz+M3AgCpKIvuDJOcHUU4lJIPxgKet9nHvDI=";
    root = "patches/runtime/gpu-runtime-pm";
    paths = [ installer ];
  };
  # Upstream asks to drop this workaround once Mesa supports GFX6-8 modifiers.
  skippedPatches."0015-TEMPORARY-drm-amd-display-hide-GFX6-8-modifiers-until-Mesa-26.3.patch" =
    lib.versionAtLeast mesa.version "26.3";

  drivers = [ driver ];
  # amdgpu builds and includes the rest of the AMD tree through relative paths.
  sources = [ "drivers/gpu/drm/amd" ];

  postPatch = ''
    grep -qxF ${lib.escapeShellArg modprobeConfig} $src/${installer} ||
      { echo "the amdgpu softdep changed upstream, see .agents/skills/kait2en/SKILL.md" >&2; exit 1; }
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
