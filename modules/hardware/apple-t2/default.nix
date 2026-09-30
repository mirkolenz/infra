{
  flake.modules.nixos.apple-t2 = {
    powerManagement.enable = true;

    # The T2 does not reliably bring its own USB devices (vendor 05ac on the
    # VHCI bus) back once it has powered them down.
    services.udev.extraRules = ''
      SUBSYSTEM=="usb", ATTR{idVendor}=="05ac", ATTR{power/control}="on", ATTR{power/autosuspend_delay_ms}="-1"
    '';

    # `nixos-hardware/apple` turns this on for the PCIe webcam of pre-T2 Macs.
    # Here the camera hangs off t2bce instead, so the module is dead weight.
    hardware.facetimehd.enable = false;
  };
}
