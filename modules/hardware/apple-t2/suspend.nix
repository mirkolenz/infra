# Broadcom Wi-Fi across S3. See `pkgs/by-name/kait2en/suspend.nix`.
# The unit mirrors the one upstream's `install-suspend-service.sh` writes.
{
  flake.modules.nixos.apple-t2 =
    { lib, pkgs, ... }:
    let
      suspend = lib.getExe pkgs.kait2en.suspend;
    in
    {
      systemd.services.kait2en-suspend = {
        description = "Kait2en T2 suspend and resume hardware fixes";
        before = [ "sleep.target" ];
        after = [
          "NetworkManager.service"
          "t2-services-suspend.service"
        ];
        wantedBy = [ "sleep.target" ];
        unitConfig.StopWhenUnneeded = true;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutStopSec = 150;
          ExecStart = "${suspend} pre";
          ExecStop = "${suspend} post";
        };
      };
    };
}
