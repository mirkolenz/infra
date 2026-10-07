{
  configurations.nixos.macbook-131.module = {
    boot.initrd.availableKernelModules = [
      "xhci_pci"
      "nvme"
      "usb_storage"
      "sd_mod"
    ];
  };
}
