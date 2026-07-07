# Hibernation (S4) for macbook-113. This Mac's firmware exposes no S3, and
# s2idle is power-hungry with the capped C-states, so the lid uses
# suspend-then-hibernate: resume fast from s2idle short-term, then hibernate
# before the battery drains.
{
  configurations.nixos.macbook-113.module =
    { lib, ... }:
    {
      # power.nix wraps the whole Sleep/Login attrset in a single mkDefault, so a
      # host block replaces it wholesale rather than merging per key. Restate every
      # key we rely on (like macbook-161 does) so nothing silently reverts to a
      # systemd default.
      systemd.sleep.settings.Sleep = {
        AllowSuspend = "yes";
        AllowHibernation = "yes";
        AllowSuspendThenHibernate = "yes";
        AllowHybridSleep = "no";
        # Fixed delay before s2idle escalates to hibernate. Kept short because
        # s2idle drains fast here (no S0ix). Overrides systemd's battery-based
        # estimation; raise it for quicker lid-reopen resume at the cost of drain.
        HibernateDelaySec = "5min";
      };

      services.logind.settings.Login = {
        HandleLidSwitch = "suspend-then-hibernate";
        HandleLidSwitchExternalPower = "suspend-then-hibernate";
        HandleLidSwitchDocked = "ignore";
      };

      # protectKernelImage (from the shared security module) forces `nohibernate`.
      # Disable it here; the swapfile lives on the LUKS-encrypted btrfs, so the
      # resume image is encrypted at rest.
      security.protectKernelImage = lib.mkForce false;

      # Resume from the swapfile on the encrypted btrfs root. Because it is a file
      # (not a partition) the kernel also needs its physical offset, which only
      # exists once the 20 GiB /swapfile has been created and changes if it is ever
      # recreated. NixOS provides no option for this, so after the first rebuild run
      # the following command and add the value below, then rebuild again:
      # sudo btrfs inspect-internal map-swapfile -r /swapfile
      boot.kernelParams = [ "resume_offset=10599087" ];
      boot.resumeDevice = "/dev/mapper/cryptroot";
    };
}
