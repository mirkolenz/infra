{
  lib,
  stdenv,
  kait2en,
}:
# In-tree drivers upstream rebuilds with one of its patch series under
# `patches/runtime`. Only these are rebuilt, the kernel stays the cached one,
# and `updates` shadows the in-tree ones. The drivers come out of the kernel's
# own source.
lib.extendMkDerivation {
  constructDrv = stdenv.mkDerivation;
  excludeDrvArgNames = [
    "skippedPatches"
    "sources"
    "drivers"
  ];
  extendDrvArgs =
    finalAttrs:
    {
      # Its `root` is the patch series.
      src,
      # Patches of the series mapped to whether to skip them, such as those the
      # pinned kernel or userspace makes unnecessary. Each must stay in the series.
      skippedPatches ? { },
      # The Kbuild directories to build.
      drivers,
      # Further parts of the kernel source the drivers include.
      sources ? [ ],
      # Passed to Kbuild after the kernel's own.
      makeFlags ? [ ],
      postPatch ? "",
      passthru ? { },
      meta ? { },
      ...
    }:
    let
      inherit (kait2en.modules) kernel;
      inherit (kait2en.modules.linuxPackages) kernelModuleMakeFlags;
      patches = "${src}/${src.root}";
      members = map (dir: "linux-${kernel.version}/${dir}") (drivers ++ sources);
      driverDirs = map (dir: "$PWD/${dir}") drivers;
    in
    {
      unpackPhase = ''
        runHook preUnpack

        tar -xf ${kernel.src} ${lib.escapeShellArgs members}
        cd linux-${kernel.version}
        # Trace headers name their directory relative to this one of the kernel tree.
        mkdir -p include/trace

        runHook postUnpack
      '';

      nativeBuildInputs = kernel.moduleBuildDependencies;
      hardeningDisable = [ "pic" ];

      # Like upstream, a patch already in the kernel is skipped. The forward check
      # comes first, since `--batch` flips a reverse run of an unapplied patch.
      postPatch = ''
        declare -A skipped=(${
          lib.concatMapAttrsStringSep " " (
            name: skip: "[${lib.escapeShellArg name}]=${lib.boolToString skip}"
          ) skippedPatches
        })

        while IFS= read -r entry || [ -n "$entry" ]; do
          case "$entry" in "" | "#"*) continue ;; esac

          file="${patches}/$entry"

          if [[ ''${skipped[$entry]:-} == true ]]; then
            echo "skipping $entry"
          elif patch -p1 --dry-run --batch --forward --fuzz=3 < "$file" > /dev/null; then
            patch -p1 --batch --forward --fuzz=3 --no-backup-if-mismatch < "$file"
          elif patch -p1 --dry-run --batch --reverse --fuzz=3 < "$file" > /dev/null; then
            echo "$entry is already present in ${kernel.version}"
          else
            echo "$entry does not apply to ${kernel.version}" >&2
            exit 1
          fi

          unset "skipped[$entry]"
        done < "${patches}/series"

        if (( ''${#skipped[@]} )); then
          echo "''${!skipped[*]} left the upstream series, see .agents/skills/kait2en/SKILL.md" >&2
          exit 1
        fi
      ''
      + postPatch;

      makeFlags = kernelModuleMakeFlags ++ makeFlags;

      # Read by `kait2en.upstream-check`.
      passthru = passthru // {
        inherit skippedPatches;
      };

      buildPhase = ''
        runHook preBuild

        appendToVar makeFlags "KCFLAGS=-I$PWD/include/trace"
        ${kait2en.kbuild "modules" driverDirs}

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall

        ${kait2en.kbuild "modules_install" driverDirs}

        (cd $src && ${kait2en.installLicenses finalAttrs.pname})

        runHook postInstall
      '';

      strictDeps = true;
      __structuredAttrs = true;

      meta = kait2en.commonMeta // meta;
    };
}
