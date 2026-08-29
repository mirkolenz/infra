{
  configurations.nixos.macbook-91.module =
    {
      config,
      lib,
      modulesPath,
      ...
    }:
    {
      imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "ehci_pci"
        "ahci"
        "firewire_ohci"
        "usbhid"
        "usb_storage"
        "sd_mod"
        "sr_mod"
        "sdhci_pci"
      ];
      boot.kernelModules = [ "kvm-intel" ];

      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
}
