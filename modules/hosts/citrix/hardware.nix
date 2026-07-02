# Xen PVHVM guest tuning: paravirtual disk driver in the initrd, the Xen console,
# and the XenServer VM Tools guest agent. The PV drivers ship with the kernel.
# - https://docs.xenserver.com/en-us/xenserver/8/vms/linux.html
# - https://docs.xcp-ng.org/vms/
# - https://github.com/xenserver/xe-guest-utilities
{
  configurations.nixos.citrix.module =
    { modulesPath, ... }:
    {
      imports = [
        (modulesPath + "/installer/scan/not-detected.nix")
      ];

      boot.initrd = {
        # Citrix Hypervisor / XCP-ng run Linux as PVHVM, so the root disk is a Xen
        # paravirtual block device (/dev/xvda). xen-blkfront is built as a module
        # (CONFIG_XEN_BLKDEV_FRONTEND=m), so it must be forced into the initrd or
        # the root filesystem (mounted by label) is unreachable at boot. xen-netfront
        # is forced alongside it for parity with the upstream xen-domU profile.
        kernelModules = [
          "xen-blkfront"
          "xen-netfront"
        ];
        # Fallbacks: emulated SATA/IDE for the brief pre-unplug HVM window, and
        # virtio so the same image also boots under plain QEMU for local testing.
        availableKernelModules = [
          "ahci"
          "ata_piix"
          "sd_mod"
          "sr_mod"
          "virtio_pci"
          "virtio_blk"
        ];
      };

      # hvc0 is the Xen paravirtual console (built in: CONFIG_HVC_XEN=y) that
      # `xe console` / XenCenter attach to; tty0 is the emulated VGA console.
      boot.kernelParams = [
        "console=tty0"
        "console=hvc0"
      ];
    };
}
