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

  # Like upstream, a patch already in the kernel is skipped.
  postPatch = ''
    grep -qxF ${lib.escapeShellArg modprobeConfig} ${upstream}/scripts/fedora/install-gpu-runtime-pm.sh ||
      { echo "the amdgpu softdep changed upstream, see pkgs/by-name/kait2en/README.md" >&2; exit 1; }

    while IFS= read -r entry || [ -n "$entry" ]; do
      case "$entry" in "" | "#"*) continue ;; esac

      file="${patches}/$entry"

      if patch -p1 --dry-run --batch --reverse --fuzz=3 < "$file" > /dev/null; then
        echo "$entry is already present in ${kernel.version}"
      else
        patch -p1 --batch --forward --fuzz=3 --no-backup-if-mismatch < "$file"
      fi
    done < "${patches}/series"

    # Resolved against the kernel tree in-tree, but against `M=` out of it.
    substituteInPlace ${driver}/amdgpu_trace.h --replace-fail \
      '#define TRACE_INCLUDE_PATH ../../drivers/gpu/drm/amd/amdgpu' \
      '#define TRACE_INCLUDE_PATH .'
  '';

  buildPhase = ''
    runHook preBuild

    make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
      -j"$NIX_BUILD_CORES" "''${makeFlags[@]}" M="$PWD/${driver}" modules

    runHook postBuild
  '';

  makeFlags = kernelModuleMakeFlags;

  # `updates` shadows the in-tree amdgpu, as for `kait2en.modules`.
  installPhase = ''
    runHook preInstall

    install -Dm444 -t "$out/lib/modules/${kernel.modDirVersion}/updates" ${driver}/amdgpu.ko

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
