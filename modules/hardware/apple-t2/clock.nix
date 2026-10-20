# The SMC clock `t2smc` registers. The kernel's NTP writeback stops at the CMOS
# clock the kernel parameters blacklist, so it never reaches the SMC, and t2smc
# only writes it before suspend and at shutdown. Upstream writes it once the
# time is synchronized at boot, here timesyncd flags that with a file.
# https://github.com/kaiT2en/KaiT2en-Fedora/blob/main/scripts/fedora/install-rtc-sync.sh
{
  flake.modules.nixos.apple-t2 =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    lib.mkIf config.services.timesyncd.enable {
      systemd.paths.apple-t2-rtc-sync = {
        description = "Wait for the system time to be synchronized";
        wantedBy = [ "multi-user.target" ];
        pathConfig.PathExists = "/run/systemd/timesync/synchronized";
      };

      systemd.services.apple-t2-rtc-sync = {
        description = "Write the synchronized system time to the T2 SMC clock";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${lib.getExe' pkgs.util-linux "hwclock"} --systohc --utc";
        };
      };
    };
}
