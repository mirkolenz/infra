# The keyboard hangs off the T2's virtual USB bus, which enumerates one device
# every ~260ms and reaches it around 3.5s into boot. The NVMe is ready at ~1.5s,
# so systemd-cryptsetup draws a prompt that swallows keystrokes for two seconds.
# Order the unlock after a keyboard exists instead.
{
  flake.modules.nixos.apple-t2 =
    {
      config,
      lib,
      utils,
      ...
    }:
    let
      udevadm = lib.getExe' config.boot.initrd.systemd.package "udevadm";

      # Anchoring on `cryptsetup.target` would not order anything, since the
      # unlock services are only `Before` it as well.
      unlockServices = map (device: "systemd-cryptsetup@${utils.escapeSystemdPath device}.service") (
        lib.attrNames config.boot.initrd.luks.devices
      );

      shutdownTargets = [
        "initrd-switch-root.target"
        "shutdown.target"
      ];
    in
    # Without an encrypted device nothing prompts this early.
    lib.mkIf (unlockServices != [ ]) {
      # The rule below keys on `event*`, which come from the evdev handler that
      # nixpkgs builds as a module and nothing else in the initrd pulls in. The
      # prompt reads the VT, so it works while this only ever times out.
      boot.initrd.kernelModules = [ "evdev" ];

      # `60-input-id.rules` is not in the initrd, so its builtin is invoked here
      # for `ID_INPUT_KEYBOARD` and the symlink gives `udevadm wait` a path.
      # Keying on the classification also covers an external keyboard.
      boot.initrd.services.udev.rules = ''
        SUBSYSTEM=="input", ENV{ID_INPUT}=="", IMPORT{builtin}="input_id"
        SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_KEYBOARD}=="1", SYMLINK+="input/keyboard"
      '';

      boot.initrd.systemd.storePaths = [ udevadm ];

      # One keyboard serves every device, so this is a single unit.
      boot.initrd.systemd.services.wait-for-keyboard = {
        description = "Wait for a keyboard before unlocking the LUKS devices";
        wantedBy = unlockServices;
        before = unlockServices ++ shutdownTargets;
        conflicts = shutdownTargets;
        after = [ "systemd-udevd.service" ];
        # The unlock services run with `DefaultDependencies=no`, so waiting on
        # `sysinit.target` would cycle. The lists above put back what this loses.
        unitConfig.DefaultDependencies = false;
        # Only wanted, and the leading `-` keeps a timeout from failing the
        # unit, so a machine without a usable keyboard carries on.
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "-${udevadm} wait --timeout=5 /dev/input/keyboard";
        };
      };
    };
}
