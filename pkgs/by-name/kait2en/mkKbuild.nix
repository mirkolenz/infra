# Builds each Kbuild directory of `drivers`, relative to the source root,
# against the pinned kernel series with its compiler and `kernelModuleMakeFlags`.
# Those strip the modules on install and sign them through `cmd_sign`,
# as for the in-tree ones. `updates` is where DKMS puts them,
# which depmod prefers over the in-tree ones.
{
  lib,
  kait2en,
  linuxPackages_7_3,
}:
let
  # Moved deliberately, see the README. Re-exported through `passthru`,
  # so the drivers cannot be loaded into a kernel they were not built against.
  linuxPackages = linuxPackages_7_3;

  kbuild = target: ''
    for dir in "''${drivers[@]}"; do
      make -j"$NIX_BUILD_CORES" "''${makeFlags[@]}" M="$PWD/$dir" ${target}
    done
  '';
in
lib.extendMkDerivation {
  constructDrv = linuxPackages.stdenv.mkDerivation;
  extendDrvArgs =
    finalAttrs:
    {
      # Passed to Kbuild after the kernel's own.
      makeFlags ? [ ],
      passthru ? { },
      meta ? { },
      ...
    }:
    {
      nativeBuildInputs = linuxPackages.kernel.moduleBuildDependencies;
      hardeningDisable = [ "pic" ];

      makeFlags =
        linuxPackages.kernelModuleMakeFlags
        ++ [
          "-C"
          "${linuxPackages.kernel.dev}/lib/modules/${linuxPackages.kernel.modDirVersion}/build"
          "INSTALL_MOD_PATH=${placeholder "out"}"
          "INSTALL_MOD_DIR=updates"
        ]
        ++ makeFlags;

      buildPhase = ''
        runHook preBuild

        ${kbuild "modules"}

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall

        ${kbuild "modules_install"}

        (cd "$src" && ${kait2en.installLicenses finalAttrs.pname})

        runHook postInstall
      '';

      strictDeps = true;
      __structuredAttrs = true;

      passthru = {
        inherit linuxPackages;
        inherit (linuxPackages) kernel;
      }
      // passthru;

      meta = kait2en.commonMeta // meta;
    };
}
