{
  configurations.nixos.macbook-131.module = {
    # The internal keyboard sits on SPI, which the LUKS prompt needs early.
    boot.initrd.kernelModules = [
      "applespi"
      "spi_pxa2xx_platform"
      "intel_lpss_pci"
    ];

    # libinput ships the touchpad quirks, but its keyboard entry expects Apple's vendor ID,
    # which applespi leaves unset. Without it "disable-while-typing" never pairs the two.
    environment.etc."libinput/local-overrides.quirks".text = ''
      [MacBook(Pro) SPI Keyboards]
      MatchName=*Apple SPI Keyboard*
      AttrKeyboardIntegration=internal
    '';
  };
}
