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
      # The firmware cuts the SSD's power when its root port enters D3cold,
      # and the kernel has no quirk for Apple's controller.
      services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x106b", ATTR{class}=="0x010802", ATTR{d3cold_allowed}="0"
      '';

      # The BCM4350 loses power in S3 and brcmfmac never recovers it.
      # These commands also run on shutdown, so the chip is reset before a warm reboot as well.
      # Loading brcmfmac arms ARPT again, so the wake sources are fixed up after the unload.
      # XHC1, the root ports, Thunderbolt (RP05, XHC2) and the keyboard (SPIT) wake S3 spuriously.
      # LID0 can come up disarmed, leaving no way to wake from deep.
      powerManagement.powerDownCommands = ''
        ${pkgs.kmod}/bin/modprobe -r brcmfmac_wcc brcmfmac || true

        for device in XHC1 ARPT RP01 RP05 RP09 RP10 XHC2 SPIT; do
          if grep -q "^$device\s.*\*enabled" /proc/acpi/wakeup; then
            echo "$device" > /proc/acpi/wakeup
          fi
        done

        if grep -q "^LID0\s.*\*disabled" /proc/acpi/wakeup; then
          echo LID0 > /proc/acpi/wakeup
        fi

        if grep -q closed /proc/acpi/button/lid/LID0/state; then
          echo deep > /sys/power/mem_sleep
        else
          echo s2idle > /sys/power/mem_sleep
        fi
      '';
      powerManagement.resumeCommands = ''
        ${pkgs.kmod}/bin/modprobe brcmfmac
      '';
    };
}
