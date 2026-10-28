{
  lib,
  stdenv,
  kait2en,
}:
# In-tree drivers upstream rebuilds with one of its patch series under
# `patches/runtime`. Only these are rebuilt, the kernel stays the cached one,
# and `updates` shadows the in-tree ones.
lib.extendMkDerivation {
  constructDrv = stdenv.mkDerivation;
  excludeDrvArgNames = [
    "series"
    "mergedSince"
    "sources"
    "drivers"
  ];
  extendDrvArgs =
    finalAttrs:
    {
      series,
      # Patches upstream's installer skips from a kernel version on.
      mergedSince ? { },
      # The subtrees of the kernel source the drivers need.
      sources,
      # The Kbuild directories to build.
      drivers,
      postPatch ? "",
      meta ? { },
      ...
    }:
    let
      inherit (kait2en.modules) kernel;
      inherit (kait2en.modules.linuxPackages) kernelModuleMakeFlags;
      upstream = kait2en.modules.src;
      patches = "${upstream}/patches/runtime/${series}";
      merged = lib.attrNames (lib.filterAttrs (_: lib.versionAtLeast kernel.version) mergedSince);
      members = map (dir: "linux-${kernel.version}/${dir}") sources;
      driverDirs = map (dir: "$PWD/${dir}") drivers;
    in
    {
      inherit (kait2en.modules) version;
      inherit (kernel) src;

      unpackPhase = ''
        runHook preUnpack

        tar -xf "$src" ${lib.escapeShellArgs members}
        cd linux-${kernel.version}

        runHook postUnpack
      '';

      nativeBuildInputs = kernel.moduleBuildDependencies;
      hardeningDisable = [ "pic" ];

      # Like upstream, a patch already in the kernel is skipped. The forward check
      # comes first, since `--batch` flips a reverse run of an unapplied patch.
      postPatch = ''
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
      ''
      + postPatch;

      makeFlags = kernelModuleMakeFlags;

      buildPhase = ''
        runHook preBuild

        ${kait2en.kbuild "modules" driverDirs}

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall

        ${kait2en.kbuild "modules_install" driverDirs}

        (cd ${upstream} && ${kait2en.installLicenses finalAttrs.pname})

        runHook postInstall
      '';

      strictDeps = true;
      __structuredAttrs = true;

      meta = kait2en.commonMeta // meta;
    };
}
