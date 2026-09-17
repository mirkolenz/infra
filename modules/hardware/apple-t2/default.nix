{
  flake.modules.nixos.apple-t2 =
    { pkgs, ... }:
    {
      # Declared and checked against upstream in `kait2en/modules.nix`.
      boot.kernelParams = pkgs.kait2en.modules.kernelParams ++ [
        # Upstream adds this on the models with an AMD dGPU, and it is inert
        # without one.
        "amdgpu.aspm=1"
      ];

      powerManagement.enable = true;

      # A boot where `graphics.nix` did not park the dGPU leaves mutter free to
      # land on amdgpu, so point it at the Intel one and cap the dGPU meanwhile.
      # https://gitlab.gnome.org/GNOME/mutter/-/blob/main/doc/multi-gpu.md
      # The T2 does not reliably bring its own USB devices (vendor 05ac on the
      # VHCI bus) back once it has powered them down.
      services.udev.extraRules = ''
        SUBSYSTEM=="drm", ENV{DEVTYPE}=="drm_minor", ENV{DEVNAME}=="/dev/dri/card[0-9]", SUBSYSTEMS=="pci", ATTRS{vendor}=="0x8086", TAG+="mutter-device-preferred-primary"
        SUBSYSTEM=="drm", DRIVERS=="amdgpu", ATTR{device/power_dpm_force_performance_level}="low"
        SUBSYSTEM=="usb", ATTR{idVendor}=="05ac", ATTR{power/control}="on", ATTR{power/autosuspend_delay_ms}="-1"
      '';

      # `nixos-hardware/apple` turns this on for the PCIe webcam of pre-T2 Macs.
      # Here the camera hangs off t2bce instead, so the module is dead weight.
      hardware.facetimehd.enable = false;
    };
}
