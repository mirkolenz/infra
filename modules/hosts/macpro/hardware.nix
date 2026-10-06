{
  configurations.nixos.macpro.module = {
    boot.initrd.availableKernelModules = [
      "uhci_hcd"
      "ehci_pci"
      "ahci"
      "firewire_ohci"
      "usb_storage"
      "usbhid"
      "sd_mod"
      "sr_mod"
    ];
  };
}
