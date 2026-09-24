# Out-of-tree drivers for Macs with an Apple T2 security chip, shipped upstream
# as DKMS packages and built here against a stock nixpkgs kernel. Unlike the
# t2linux patch set they replace, nothing here rebuilds the kernel.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/modules
{
  lib,
  stdenv,
  fetchFromGitHub,
  kait2en,
  linuxPackages_latest,
  nix-update-script,
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

  # The built-in counterparts of `replacedModules`: a driver compiled into the
  # kernel is past every blacklist, so it is stopped at its initcall instead.
  initcallBlacklist = [
    "cmos_init"
    "magicmouse_driver_init"
  ];

  kernelParams = [
    # The t2bce stack needs the IOMMU, audio and suspend need it passed through,
    # and `pm_async=off` serialises the resume ordering the T2 depends on.
    "intel_iommu=on"
    "iommu=pt"
    "pm_async=off"
    # The Broadcom part wedges when it brings up a peer-to-peer interface.
    "brcmfmac.p2pon=0"
    # Apple leaves ASPM disabled in firmware.
    "pcie_aspm=force"
    "pcie_aspm.policy=powersave"
    "pcie_ports=compat"
    "i915.enable_guc=2"
    # S3, not s2idle: the T2 only reaches its low power state on the deep path,
    # and `t2smp` offlines the secondary CPUs so resume does not crawl.
    "mem_sleep_default=deep"
  ];

  # Each list above mirrors an array in an upstream installer script, which
  # `postPatch` diffs against it so a bump fails loudly instead of silently.
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
      array = "BLACKLIST_MODULES";
      values = replacedModules;
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
  # own: `nix-update` writes to wherever `meta.position` points.
  version = "0.1.12-unstable-2026-09-24";

  # `rev` is moved twice a day by CI, while the marker below moves only when
  # someone reads the diff that came with it, so the two together delimit what
  # is still unreviewed. It is kept short, since nix-update rewrites every
  # occurrence of the full `rev` in this file. See README.md.
  # reviewed-rev: d8892d8e2ad6
  src = fetchFromGitHub {
    owner = "kaiT2en";
    repo = "KaiT2en-Fedora";
    rev = "fbc43ad316312228e27d70aa39710fb44dd1464f";
    hash = "sha256-3pt65u7DlQMYmgozDw4Qtzc585Vt7JuRo6EtAGZA2Cw=";
  };

  nativeBuildInputs = kernel.moduleBuildDependencies;
  hardeningDisable = [ "pic" ];

  # The drift check runs here rather than in a `checkPhase`, so a moved list
  # fails in a second instead of after eleven modules have compiled.
  postPatch = ''
    # Prints one element per line of a bash array literal, however it is wrapped.
    upstreamArray() {
      awk -v name="$2" '
        index($0, name "=(") == 1 { open = 1; sub(/^[^(]*\(/, "") }
        open {
          if (sub(/\).*/, "")) open = 2
          sub(/#.*/, ""); gsub(/"/, "")
          for (i = 1; i <= NF; i++) print $i
          if (open == 2) exit
        }
      ' "$1" | sort
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
      initcallBlacklist
      kernel
      kernelParams
      replacedModules
      ;
    # The set itself, so the NixOS module does not instantiate a second one.
    linuxPackages = linuxPackages_latest;
    # `nix-update -s` moves the pin, then refreshes each `cargoHash` against it
    # in the same process. Separate update scripts would race.
    inherit (kait2en)
      ave
      journal
      touchid
      ;
    updateScript = nix-update-script {
      extraArgs = [
        "--version=branch"
        "--subpackage=touchid"
        "--subpackage=journal"
        "--subpackage=ave"
      ];
    };
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
