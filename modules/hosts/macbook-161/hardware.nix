{
  configurations.nixos.macbook-161.module =
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
        "nvme"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];
      boot.initrd.kernelModules = [ ];
      boot.kernelModules = [ "kvm-intel" ];
      boot.extraModulePackages = [ ];

      # Mount existing macOS EFI partition (shared with macOS bootloader)
      fileSystems."/boot" = {
        device = "/dev/disk/by-id/nvme-APPLE_SSD_AP1024N_C02001700E3N9V014-part1";
        fsType = "vfat";
        options = [ "umask=0077" ];
      };

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
}
