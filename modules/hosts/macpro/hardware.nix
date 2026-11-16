{
  configurations.nixos.macpro.module = {
    # Logs corrected and uncorrected ECC memory errors.
    hardware.rasdaemon.enable = true;

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
