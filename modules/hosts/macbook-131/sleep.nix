# Suspend for the MacBookPro13,1.
# The firmware has no S0ix, so s2idle draws about 4 W while S3 (deep) stays below 1 W.
# Under deep only the lid wakes the machine, which the EC treats as a level:
# a suspend entered with the lid open wakes again at once.
# So the mode is picked per suspend, deep with the lid shut and s2idle with it open.
# Shutting the lid during s2idle wakes the machine, and logind suspends it again into deep.
# https://github.com/federal1970/macbookpro13-1-fedora#sleep-and-hibernation
{
  configurations.nixos.macbook-131.module =
    { pkgs, ... }:
    {
      # 7.2 is what the MacBookPro13,1 community setups validate S3 against.
      boot.kernelPackages = pkgs.linuxPackages_latest;

      # The firmware cuts the SSD's power when its root port enters D3cold,
      # and the kernel has no quirk for Apple's controller.
      # Matched by ID because the controller does not report the NVMe class code.
      services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x106b", ATTR{device}=="0x2003", ATTR{d3cold_allowed}="0"
      '';

      # The BCM4350 loses power in S3 and brcmfmac never recovers it.
      # These commands also run on shutdown, so the chip is reset before a warm reboot as well.
      # Loading brcmfmac arms ARPT again, so the wake sources are fixed up after the unload.
      # XHC1, the root ports and Thunderbolt (RP05, XHC2) wake S3 spuriously.
      # LID0 can come up disarmed, leaving no way to wake from deep.
      # The keyboard (SPIT) wakes S3 spuriously too, but is the only way to wake s2idle with the lid open.
      powerManagement.powerDownCommands = ''
        ${pkgs.kmod}/bin/modprobe -r brcmfmac_wcc brcmfmac || true

        # Writing a device to /proc/acpi/wakeup toggles it.
        wakeup() {
          if ! grep -q "^$1\s.*\*$2" /proc/acpi/wakeup; then
            echo "$1" > /proc/acpi/wakeup
          fi
        }

        for device in XHC1 ARPT RP01 RP05 RP09 RP10 XHC2; do
          wakeup "$device" disabled
        done

        wakeup LID0 enabled

        if grep -q closed /proc/acpi/button/lid/LID0/state; then
          wakeup SPIT disabled
          echo deep > /sys/power/mem_sleep
        else
          wakeup SPIT enabled
          echo s2idle > /sys/power/mem_sleep
        fi
      '';
      powerManagement.resumeCommands = ''
        ${pkgs.kmod}/bin/modprobe brcmfmac
      '';
    };
}
