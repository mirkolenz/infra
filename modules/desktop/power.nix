# Laptop power management: lid-switch handling and suspend (no hibernation).
{
  flake.modules.nixos.base =
    {
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.graphical.enable {
      services.logind.settings.Login = {
        HandleLidSwitch = lib.mkDefault "sleep";
        HandleLidSwitchExternalPower = lib.mkDefault "sleep";
        HandleLidSwitchDocked = lib.mkDefault "ignore";
      };

      systemd.sleep.settings.Sleep = {
        AllowSuspend = lib.mkDefault "yes";
        AllowHibernation = lib.mkDefault "no";
        AllowSuspendThenHibernate = lib.mkDefault "no";
        AllowHybridSleep = lib.mkDefault "no";
      };
    };
}
