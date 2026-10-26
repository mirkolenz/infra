# The CS8409 codec driver with the setup of Apple's amplifiers, which the in-tree one lacks,
# so the speakers and the internal microphone of Macs without a T2 chip work.
# Patches the codec sources of the kernel and builds them out of tree, so nothing rebuilds the kernel.
{
  lib,
  stdenv,
  fetchFromGitHub,
  kernel,
  kernelModuleMakeFlags,
  nix-update-script,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "snd-hda-macbookpro";
  version = "0-unstable-2026-09-06";

  src = fetchFromGitHub {
    owner = "davidjo";
    repo = "snd_hda_macbookpro";
    rev = "89b22ff90b86468b186706861dd18663562defa7";
    hash = "sha256-5iDybAlRG5HldUA24L9+rSlgEiUPZg50K8IYC+Lie4U=";
  };

  postUnpack = ''
    tar -xf ${kernel.src} -C "$sourceRoot" --strip-components=3 linux-${kernel.version}/sound/hda/{codecs,common}
  '';

  patches = [
    "${finalAttrs.src}/patch_cs8409.c.diff"
    "${finalAttrs.src}/patch_cs8409.h.diff"
  ];

  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = kernelModuleMakeFlags ++ [
    "-C"
    "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "M=$(PWD)/codecs/cirrus"
    # Skips the other Cirrus drivers, which upstream leaves unpatched.
    "CONFIG_SND_HDA_CODEC_CS420X="
    "CONFIG_SND_HDA_CODEC_CS421X="
    # The flags of upstream's Makefile, plus its headers the patched driver includes.
    "KCFLAGS=-DAPPLE_PINSENSE_FIXUP -DAPPLE_CODECS -DCONFIG_SND_HDA_RECONFIG=1 -Wno-unused-variable -Wno-unused-function -I${finalAttrs.src}/patch_cirrus"
  ];

  # `modules_install` signs the module through `kernelModuleMakeFlags`,
  # and depmod prefers `updates` over the in-tree driver.
  installFlags = [
    "INSTALL_MOD_PATH=${placeholder "out"}"
    "INSTALL_MOD_DIR=updates"
  ];

  installTargets = [ "modules_install" ];

  passthru.updateScript = nix-update-script { extraArgs = [ "--version=branch" ]; };

  strictDeps = true;
  __structuredAttrs = true;

  meta = {
    description = "Kernel driver for the CS8409 audio codec in Macs";
    homepage = "https://github.com/davidjo/snd_hda_macbookpro";
    license = lib.licenses.gpl2Only;
    maintainers = with lib.maintainers; [ mirkolenz ];
    platforms = lib.platforms.linux;
    # Only used on one host, and each kernel bump rebuilds it.
    hydraPlatforms = [ ];
    # Upstream's patches target the codec layout of 6.17.
    broken = kernel.kernelOlder "6.17";
  };
})
