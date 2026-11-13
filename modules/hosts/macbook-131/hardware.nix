{
  configurations.nixos.macbook-131.module = {
    boot.initrd.availableKernelModules = [
      "xhci_pci"
      "nvme"
      "usb_storage"
      "sd_mod"
    ];

    # Cheaper on the dual-core CPU than zstd.
    boot.zswap.compressor = "lz4";

    # xhci_pci lets the Alpine Ridge xHCI below root port 1c.4 runtime-suspend,
    # but on Macs a plug never wakes the suspended controller,
    # so USB-C devices stay undetected until the driver is rebound.
    # `bind` follows the driver's own `pm_runtime_allow` at probe, `add` covers coldplug.
    # https://github.com/omacom/omarchy/pull/7044
    services.udev.extraRules = ''
      ACTION=="add|bind", SUBSYSTEM=="pci", DEVPATH=="/devices/pci0000:00/0000:00:1c.4/*", ATTR{class}=="0x0c0330", ATTR{power/control}="on"
    '';
  };
}
