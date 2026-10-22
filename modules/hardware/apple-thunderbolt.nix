# Thunderbolt across suspend on Intel MacBooks.
# Suspending the controller runs Apple's ACPI `_PS3`, which cuts its power,
# and `_PS0` on resume never restores it, leaving the ports dead until a cold boot.
# Unbound, the controller stays powered and USB-C devices keep working,
# since they attach through the controller's own xHCI without this driver.
# https://wiki.archlinux.org/title/Power_management#Suspend/resume_service_files
{
  flake.modules.nixos.apple-thunderbolt =
    { pkgs, ... }:
    {
      systemd.services.thunderbolt-suspend = {
        description = "Unload the thunderbolt kernel module across suspend";
        before = [ "sleep.target" ];
        wantedBy = [ "sleep.target" ];
        unitConfig.StopWhenUnneeded = true;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "-${pkgs.kmod}/bin/modprobe -r thunderbolt";
          ExecStop = "${pkgs.kmod}/bin/modprobe thunderbolt";
        };
      };
    };
}
