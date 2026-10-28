# https://wiki.nixos.org/wiki/NixOS_on_ARM/Raspberry_Pi_4
{ inputs, ... }:
{
  configurations.nixos.raspi.module =
    { pkgs, ... }:
    {
      imports = [ "${inputs.nixos-hardware}/raspberry-pi/4" ];

      # The mainline kernel comes from the binary cache, unlike the vendor one of nixos-hardware.
      boot.kernelPackages = pkgs.linuxPackages;

      # The mini UART is serial1 in the mainline device tree.
      boot.kernelParams = [
        "console=ttyS1,115200n8"
        "console=tty1"
      ];

      # Cheaper on the Pi's CPU than zstd.
      boot.zswap.compressor = "lz4";

      # Rewrites boot code, U-Boot and config.txt on every switch.
      hardware.raspberry-pi.firmware = {
        enable = true;
        # firmware, U-Boot and extlinux share one FAT partition, see disk.nix
        path = "/boot";
        uboot.enable = true;
      };
      # keeps the firmware from drawing warning icons over the framebuffer of the kernel
      hardware.raspberry-pi.configtxt.settings.all.avoid_warnings = true;
      # Overclock cooled by the PoE+ HAT fan, the firmware scales the voltage on its own.
      # A fixed over_voltage would disable that, use over_voltage_delta if it turns unstable.
      # https://www.raspberrypi.com/documentation/computers/config_txt.html#overclocking
      hardware.raspberry-pi.configtxt.settings.pi4.arm_freq = 2000;

      # U-Boot hands the kernel the mainline device tree of the generation,
      # as vc4 fails on the vendor one that the firmware would pass on.
      boot.loader.generic-extlinux-compatible.useGenerationDeviceTree = true;
      hardware.deviceTree = {
        filter = "bcm2711-rpi-4-b.dtb";
        overlays = [
          {
            name = "rpi-poe-plus";
            dtsFile = ./rpi-poe-plus.dts;
          }
        ];
      };

      # Without an RTC, the clock boots at the systemd release date until NTP corrects it,
      # so calendar timers would fire right away. They are ordered after time-sync.target.
      systemd.additionalUpstreamSystemUnits = [ "systemd-time-wait-sync.service" ];
      systemd.services.systemd-time-wait-sync.wantedBy = [ "sysinit.target" ];

      environment.systemPackages = with pkgs; [
        raspberrypi-eeprom
      ];
    };
}
