# Hibernation (S4) for macbook-113. This Mac's firmware exposes no S3, and
# s2idle is power-hungry with the capped C-states, so the lid uses
# suspend-then-hibernate: resume fast from s2idle short-term, then hibernate
# before the battery drains.
{
  configurations.nixos.macbook-113.module =
    { lib, ... }:
    {
      systemd.sleep.settings.Sleep = {
        AllowHibernation = "yes";
        AllowSuspendThenHibernate = "yes";
        # Fixed delay before s2idle escalates to hibernate. Kept short because
        # s2idle drains fast here (no S0ix). Overrides systemd's battery-based
        # estimation; raise it for quicker lid-reopen resume at the cost of drain.
        HibernateDelaySec = "5min";
      };

      services.logind.settings.Login = {
        HandleLidSwitch = "suspend-then-hibernate";
        HandleLidSwitchExternalPower = "suspend-then-hibernate";
      };

      # protectKernelImage (from the shared security module) forces `nohibernate`.
      # Disable it here; the swapfile lives on the LUKS-encrypted btrfs, so the
      # resume image is encrypted at rest.
      security.protectKernelImage = lib.mkForce false;
    };
}
