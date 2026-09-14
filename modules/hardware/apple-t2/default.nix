# Support for Macs with an Apple T2 security chip, replacing the upstream
# `nixos-hardware/apple/t2` module: the t2bce driver stack needs a different
# kernel config and a different audio setup than the one shipped upstream.
# Shared by the macbook-161 host and the T2 installer ISO.
# https://wiki.t2linux.org/guides/postinstall/
# https://github.com/NixOS/nixos-hardware/blob/master/apple/t2/default.nix
{
  flake.modules.nixos.apple-t2 = {
    boot.kernelParams = [
      # Needed for audio and suspend, post-resume.service comes from powerManagement
      "intel_iommu=on"
      "iommu=pt"
      "pm_async=off"
      # The firmware picks deep (S3) here, where the T2 cuts power to its own USB
      # bus the longer the machine stays suspended and then fails to bring the
      # devices back, so a wake after an hour or so lands in a session with a
      # dead keyboard and touch bar. Pin s2idle, which keeps the bus powered.
      # "mem_sleep_default=s2idle"
      # Macs with hybrid graphics hand the internal panel to the dGPU, so the
      # console only appears once amdgpu has taken over, which on these machines
      # freezes for minutes at a time.
      # The t2 patch set defers every display driver until apple-gmux has probed,
      # hence the switch has to be requested from the module rather than from the
      # firmware, and a modprobe option would come too late for the initrd.
      # https://wiki.t2linux.org/guides/hybrid-graphics/
      "apple_gmux.force_igd=1"
    ];

    powerManagement.enable = true;

    # `force_igd` only moves the panel to the iGPU, it does not keep the dGPU
    # idle: mutter picks its own primary GPU and lands on amdgpu, so the dGPU
    # ramps up as soon as a GNOME session starts compositing. On these machines
    # that transient trips CPU CATERR and the SMC cuts power, which looks like a
    # spontaneous reboot a few seconds into the session. Point mutter at the
    # Intel GPU (the only 0x8086 display device here) and cap what the dGPU may
    # draw if something still renders on it.
    # https://wiki.t2linux.org/guides/hybrid-graphics/
    # https://gitlab.gnome.org/GNOME/mutter/-/blob/main/doc/multi-gpu.md
    # The T2 exposes the keyboard, trackpad, touch bar, camera and headset as USB
    # devices of its own (vendor 05ac on the VHCI bus), and does not reliably
    # bring one back once it has powered it down, so keep them out of runtime
    # suspend as well.
    services.udev.extraRules = ''
      SUBSYSTEM=="drm", ENV{DEVTYPE}=="drm_minor", ENV{DEVNAME}=="/dev/dri/card[0-9]", SUBSYSTEMS=="pci", ATTRS{vendor}=="0x8086", TAG+="mutter-device-preferred-primary"
      SUBSYSTEM=="drm", DRIVERS=="amdgpu", ATTR{device/power_dpm_force_performance_level}="low"
      SUBSYSTEM=="usb", ATTR{idVendor}=="05ac", ATTR{power/control}="on", ATTR{power/autosuspend_delay_ms}="-1"
    '';

    # The t2bce stack needs iommu=pt, which identity-maps DMA for every device,
    # so close the only hotpluggable DMA path: PCIe tunnels are set up by this
    # driver alone and none get approved without it. USB-C keeps working, since
    # the Thunderbolt controller muxes DisplayPort itself and exposes a plain
    # xHCI function, but the PCIe-side devices of a dock and eGPUs do not.
    boot.blacklistedKernelModules = [ "thunderbolt" ];

    # The T2 chip exposes an internal USB ethernet interface with no Linux support.
    # Keep it down in networkd and hide it from NetworkManager, otherwise the
    # `*-wait-online` units block `network-online.target` until they time out.
    systemd.network.networks."10-t2-ethernet" = {
      matchConfig.MACAddress = "ac:de:48:00:11:22";
      linkConfig = {
        ActivationPolicy = "manual";
        RequiredForOnline = false;
      };
    };

    networking.networkmanager.unmanaged = [ "mac:ac:de:48:00:11:22" ];

    # `nixos-hardware/apple` turns this on for the PCIe webcam of pre-T2 Macs.
    # On T2 Macs the camera hangs off the t2bce USB host controller instead, and
    # the out-of-tree module would only pull the `dev` output of the patched
    # kernel into the closure, which forces a full kernel rebuild wherever just
    # the runtime output is cached.
    hardware.facetimehd.enable = false;
  };
}
