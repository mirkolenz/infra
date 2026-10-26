{
  configurations.nixos.macbook-131.module = {
    # The PCIe camera (Broadcom 1570) has no in-tree driver.
    hardware.facetimehd.enable = true;

    boot.initrd.availableKernelModules = [
      "xhci_pci"
      "nvme"
      "usb_storage"
      "sd_mod"
    ];
  };
}
