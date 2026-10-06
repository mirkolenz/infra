{
  configurations.nixos.macbook-131.module = {
    # The internal keyboard sits on SPI, which the LUKS prompt needs early.
    boot.initrd.kernelModules = [
      "applespi"
      "spi_pxa2xx_platform"
      "intel_lpss_pci"
    ];

    # Touchpad quirks to make "disable-while-typing" work, from nixos-hardware's 14-1.
    environment.etc."libinput/local-overrides.quirks".text = ''
      [MacBook(Pro) SPI Touchpads]
      MatchName=*Apple SPI Touchpad*
      ModelAppleTouchpad=1
      AttrTouchSizeRange=200:150
      AttrPalmSizeThreshold=1100

      [MacBook(Pro) SPI Keyboards]
      MatchName=*Apple SPI Keyboard*
      AttrKeyboardIntegration=internal
    '';
  };
}
