# Out-of-tree drivers for Macs with an Apple T2 security chip, shipped upstream
# as DKMS packages and built here against a stock nixpkgs kernel. Unlike the
# t2linux patch set they replace, nothing here rebuilds the kernel.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/modules
{
  lib,
  stdenv,
  fetchFromGitHub,
  jq,
  kait2en,
  linuxPackages_latest,
  shfmt,
}:
let
  # Re-exported through `passthru`, so the modules cannot be loaded into a
  # kernel they were not built against.
  inherit (linuxPackages_latest) kernel kernelModuleMakeFlags;

  # One directory per DKMS package.
  packages = [
    "t2bce_stack"
    "t2smc"
    "t2bdrm"
    "t2touchbar"
    "hid_t2magicmouse"
    "t2_precision_trackpad"
    "t2_trackpad_actuator"
    "t2mfi_fastcharge"
    "t2gmux"
    "t2thunderbolt"
    "t2smp"
  ];

  # The keyboard sits behind the T2's virtual USB host controller, and t2smc
  # registers the SMC-backed clock that keeps the initrd off the epoch.
  earlyModules = [
    "t2bce_dma"
    "t2bce_core"
    "t2bce_vhci"
    "t2hid"
    "t2smc"
  ];

  # Each claims a device one of the packages above drives, and whichever binds
  # first wins.
  replacedModules = [
    "acpi_tad"
    "applesmc"
    "macsmc"
    "hid_apple"
    "hid_appletb_bl"
    "hid_appletb_kbd"
    "hid_magicmouse"
    "appletbdrm"
    "apple_bce"
    "apple_mfi_fastcharge"
    "apple_gmux"
  ];

  kernelParams = [
    # The t2bce stack needs the IOMMU, audio and suspend need it passed through,
    # and `pm_async=off` serialises the resume ordering the T2 depends on.
    "intel_iommu=on"
    "iommu=pt"
    "pm_async=off"
    # The Broadcom part wedges when it brings up a peer-to-peer interface.
    "brcmfmac.p2pon=0"
    # Apple leaves ASPM disabled in firmware, the AMD dGPU included.
    "amdgpu.aspm=1"
    "pcie_aspm=force"
    "pcie_aspm.policy=powersave"
    "pcie_ports=compat"
    "i915.enable_guc=2"
    # S3, not s2idle: the T2 only reaches its low power state on the deep path,
    # and `t2smp` offlines the secondary CPUs so resume does not crawl.
    "mem_sleep_default=deep"
    # `blacklistedKernelModules` only suppresses loading by alias, which leaves
    # a module something asks for by name.
    "module_blacklist=${lib.concatStringsSep "," replacedModules}"
    # Stopped at their init functions, since Fedora builds them into the kernel
    # where no module blacklist reaches. nixpkgs builds them as modules, whose
    # init passes the same check.
    "initcall_blacklist=cmos_init,magicmouse_driver_init"
  ];

  # Each list above mirrors the array an upstream installer script has built
  # once its assignments ran, which `postPatch` diffs against it so a bump fails
  # loudly instead of silently.
  mirrored = [
    {
      file = "scripts/fedora/install-dkms-modules.sh";
      array = "MODULES";
      values = packages;
    }
    {
      file = "scripts/fedora/rebuild-initramfs.sh";
      array = "EARLY_MODULES";
      values = earlyModules;
    }
    {
      file = "scripts/fedora/install-kernel-args.sh";
      array = "ADD_ARGS";
      values = kernelParams;
    }
  ];
in
stdenv.mkDerivation {
  pname = "kait2en-modules";

  # The pin every package here is built from. It cannot live in a file of its
  # own: `nix-update` writes to wherever the `src` attribute is declared.
  version = "0.1.12-unstable-2026-10-05";

  src = fetchFromGitHub {
    owner = "kaiT2en";
    repo = "KaiT2en-Fedora";
    rev = "a88f36f452676bdcf840a5d958478e49d221c384";
    hash = "sha256-uiD5JiahqC+VJmjlqoA1BILFMoC1kl6z8QhU4mn/rDQ=";
  };

  nativeBuildInputs = kernel.moduleBuildDependencies ++ [
    jq
    shfmt
  ];
  hardeningDisable = [ "pic" ];

  # The drift check runs here rather than in a `checkPhase`, so a moved list
  # fails in a second instead of after every module has compiled.
  postPatch = ''
    # Prints the named array as a script leaves it after its top-level
    # assignments. shfmt parses those out, so nothing else in it runs.
    upstreamArray() {
      local assignments
      assignments=$(shfmt --to-json <"$1" |
        jq '.Stmts |= map(select(.Cmd.Type == "CallExpr" and .Cmd.Args == null))' |
        shfmt --from-json)

      (
        # Some call helpers from the unsourced `lib.sh`, which only leaves
        # those variables empty.
        eval "$assignments" || true
        local -n array=$2
        printf '%s\n' "''${array[@]}"
      ) | sort
    }

    ${lib.concatMapStringsSep "\n" (
      {
        file,
        array,
        values,
      }:
      ''
        diff -u <(upstreamArray ${file} ${array}) \
          <(printf '%s\n' ${lib.escapeShellArgs values} | sort) ||
          { echo "${array} in ${file} changed upstream, see pkgs/by-name/kait2en/README.md" >&2; exit 1; }
      ''
    ) mirrored}

    # One Kbuild unit, so its members have to be staged into it. Built
    # separately they would each get their own symbol versions.
    cp -r modules/t2bce_{dma,core,vhci,audio} modules/t2bce_stack/
    cp -r t2-services/t2-ave/kernel/t2bce_ave modules/t2bce_stack/

    # Fedora enables these through AVE's Kconfig `select`, which an out-of-tree
    # build cannot apply, so stage only the ones the stock kernel lacks.
    stageKernelModule() {
      local config=$1 source=$2 module
      module="''${source##*/}"

      if grep -q "^CONFIG_$config=[ym]$" ${kernel.configfile}; then
        return
      fi

      # `--occurrence=1` stops at the match instead of scanning the whole tree.
      tar -xOf ${kernel.src} --occurrence=1 "linux-${kernel.version}/$source" \
        > "modules/t2bce_stack/$module"
      printf 'obj-m += %s\n' "''${module%.c}.o" >> modules/t2bce_stack/Makefile
    }

    stageKernelModule V4L2_MEM2MEM_DEV drivers/media/v4l2-core/v4l2-mem2mem.c
    stageKernelModule VIDEOBUF2_VMALLOC drivers/media/common/videobuf2/videobuf2-vmalloc.c
  '';

  # The upstream Makefiles disagree on these names and all default to `uname -r`.
  makeFlags = kernelModuleMakeFlags ++ [
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "KERNEL_SRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "KVER=${kernel.modDirVersion}"
    "KVERSION=${kernel.modDirVersion}"
    "KERNEL_RELEASE=${kernel.modDirVersion}"
  ];

  buildPhase = ''
    runHook preBuild

    for package in ${lib.escapeShellArgs packages}; do
      make -C "modules/$package" -j"$NIX_BUILD_CORES" "''${makeFlags[@]}"
    done

    runHook postBuild
  '';

  # `updates` is where DKMS puts them, and depmod prefers it over the in-tree one.
  installPhase = ''
    runHook preInstall

    find modules -name '*.ko' -exec \
      install -Dm444 -t "$out/lib/modules/${kernel.modDirVersion}/updates" {} +

    ${kait2en.installLicenses "kait2en-modules"}

    runHook postInstall
  '';

  # What the NixOS module needs, declared next to the upstream references.
  passthru = {
    inherit
      earlyModules
      kernel
      kernelParams
      replacedModules
      ;
    # The set itself, so the NixOS module does not instantiate a second one.
    linuxPackages = linuxPackages_latest;
    # Refresh the Cargo hashes together with the shared source pin.
    inherit (kait2en)
      ave
      journal
      power-explorer
      smc-control
      touchbar
      touchid
      ;
  };

  strictDeps = true;
  __structuredAttrs = true;

  meta = kait2en.commonMeta // {
    description = "Out-of-tree kernel drivers for Macs with an Apple T2 security chip";
    # The drivers keep the SPDX header of the kernel file they forked, which is
    # GPL-2.0-only for some and GPL-2.0-or-later for others. The t2bce stack has
    # no header and declares `MODULE_LICENSE("GPL")`, meaning or-later.
    license = with lib.licenses; [
      gpl2Only
      gpl2Plus
    ];
  };
}
