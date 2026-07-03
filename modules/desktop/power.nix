# Laptop power management: lid-switch handling and suspend (no hibernation).
{
  flake.modules.nixos.base =
    {
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.graphical.enable {
      services.logind.settings.Login = lib.mkDefault {
        HandleLidSwitch = "sleep";
        HandleLidSwitchExternalPower = "sleep";
        HandleLidSwitchDocked = "ignore";
      };

      systemd.sleep.settings.Sleep = lib.mkDefault {
        AllowSuspend = "yes";
        AllowHibernation = "no";
        AllowSuspendThenHibernate = "no";
        AllowHybridSleep = "no";
      };
    };
}
