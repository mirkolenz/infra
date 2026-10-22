# The BCM4350 carries both Wi-Fi and Bluetooth.
{
  configurations.nixos.macbook-131.module =
    { pkgs, ... }:
    {
      # A warm reboot can leave the chip unresponsive, which the firmware does not fix,
      # so both radios stay dead (`brcmf_chip_recognition: MMIO read failed`).
      # Removing brcmfmac resets the chip, done at shutdown only,
      # since brcmfmac re-probes it after suspend on its own.
      systemd.services.brcmfmac-reset = {
        description = "Reset the BCM4350 before shutdown";
        wantedBy = [ "multi-user.target" ];
        # A restart on switch would take Wi-Fi down without bringing it back.
        restartIfChanged = false;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStop = "-${pkgs.kmod}/bin/modprobe -r brcmfmac_wcc brcmfmac";
        };
      };

      # After a warm reboot the firmware can also read memory the IOMMU never mapped for it,
      # and then stops responding.
      # The chip is soldered on, so its group bypasses translation while Thunderbolt stays confined.
      # The kernel only switches the type of a group without bound drivers,
      # and udev writes it before loading brcmfmac.
      services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x14e4", ATTR{device}=="0x43a3", ATTR{iommu_group/type}="identity"
      '';
    };
}
