{
  configurations.nixos.macbook-113.module =
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
        "ahci"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];
      boot.kernelModules = [ "kvm-intel" ];

      # The internal BCM4360 (14e4:43a0) has no working in-tree/open driver: b43
      # lacks the 802.11ac PHY, brcmsmac is 802.11n-only, and brcmfmac does not
      # list this PCI id. Only the unmaintained proprietary broadcom_sta (wl)
      # supports it, which we reject. Blacklist the drivers that grab the card so
      # it stays dormant instead of spamming failed b43 probes; the machine runs
      # on wired ethernet (a USB dongle with an in-tree driver would also work).
      boot.blacklistedKernelModules = [
        "b43"
        "bcma"
        "ssb"
        "brcmsmac"
      ];

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
}
