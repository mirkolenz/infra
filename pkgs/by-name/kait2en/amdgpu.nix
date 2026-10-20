# amdgpu with upstream's GMUX runtime PM patches, which let the dGPU sleep in
# D3cold while the iGPU drives the panel and wake for PRIME and external
# displays. Only the one driver is rebuilt, the kernel stays the cached one.
# https://github.com/kaiT2en/KaiT2en-Fedora/blob/main/scripts/fedora/install-gpu-runtime-pm.sh
{
  lib,
  stdenv,
  kait2en,
}:
let
  inherit (kait2en.modules.linuxPackages) kernel kernelModuleMakeFlags;

  upstream = kait2en.modules.src;
  patches = "${upstream}/patches/runtime/gpu-runtime-pm";
  driver = "drivers/gpu/drm/amd/amdgpu";

  # Upstream writes it from a heredoc in its installer, checked in `postPatch`.
  modprobeConfig = "softdep amdgpu pre: t2gmux";

  # Backported in a form the reverse dry run below misses, so upstream's
  # installer skips them by kernel version too.
  merged = lib.optional (lib.versionAtLeast kernel.version "7.2.10") "0001-drm-amdgpu-reset-VI-ASIC-on-MacBookPro15-1.patch";
in
stdenv.mkDerivation {
  pname = "kait2en-amdgpu";
  inherit (kait2en.modules) version;

  inherit (kernel) src;

  # The patches touch nothing outside the AMD tree, but amdgpu includes a few
  # DRM core headers through relative paths, so take the whole DRM subtree.
  unpackPhase = ''
    runHook preUnpack

    tar -xf "$src" linux-${kernel.version}/drivers/gpu/drm
    cd linux-${kernel.version}

    runHook postUnpack
  '';

  nativeBuildInputs = kernel.moduleBuildDependencies;
  hardeningDisable = [ "pic" ];

  # Like upstream, a patch already in the kernel is skipped. The forward check
  # comes first, since `--batch` flips a reverse run of an unapplied patch.
  postPatch = ''
    grep -qxF ${lib.escapeShellArg modprobeConfig} ${upstream}/scripts/fedora/install-gpu-runtime-pm.sh ||
      { echo "the amdgpu softdep changed upstream, see .agents/skills/kait2en/SKILL.md" >&2; exit 1; }

    while IFS= read -r entry || [ -n "$entry" ]; do
      case "$entry" in "" | "#"*) continue ;; esac

      file="${patches}/$entry"

      if [[ " ${toString merged} " == *" $entry "* ]]; then
        echo "$entry is merged in ${kernel.version}"
      elif patch -p1 --dry-run --batch --forward --fuzz=3 < "$file" > /dev/null; then
        patch -p1 --batch --forward --fuzz=3 --no-backup-if-mismatch < "$file"
      elif patch -p1 --dry-run --batch --reverse --fuzz=3 < "$file" > /dev/null; then
        echo "$entry is already present in ${kernel.version}"
      else
        echo "$entry does not apply to ${kernel.version}" >&2
        exit 1
      fi
    done < "${patches}/series"

    # Resolved against the kernel tree in-tree, but against `M=` out of it.
    substituteInPlace ${driver}/amdgpu_trace.h --replace-fail \
      '#define TRACE_INCLUDE_PATH ../../drivers/gpu/drm/amd/amdgpu' \
      '#define TRACE_INCLUDE_PATH .'
  '';

  buildPhase = ''
    runHook preBuild

    ${kait2en.modules.kbuild "modules" "$PWD/${driver}"}

    runHook postBuild
  '';

  makeFlags = kernelModuleMakeFlags;

  # `updates` shadows the in-tree amdgpu.
  installPhase = ''
    runHook preInstall

    ${kait2en.modules.kbuild "modules_install" "$PWD/${driver}"}

    (cd ${upstream} && ${kait2en.installLicenses "kait2en-amdgpu"})

    runHook postInstall
  '';

  passthru = { inherit modprobeConfig; };

  strictDeps = true;
  __structuredAttrs = true;

  meta = kait2en.commonMeta // {
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
