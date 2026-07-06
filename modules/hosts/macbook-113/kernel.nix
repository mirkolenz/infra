{
  configurations.nixos.macbook-113.module =
    { pkgs, ... }:
    {
      boot.kernelParams = [
        "i915.modeset=0"
        # https://www.thomas-krenn.com/en/wiki/Processor_P-states_and_C-states
        "intel_idle.max_cstate=2"
        "processor.max_cstate=2"
      ];

      # The thunderbolt controller breaks suspend on this MacBook, so unload the
      # module before sleep and load it again on resume instead of blacklisting it.
      # https://wiki.archlinux.org/title/Power_management#Suspend/resume_service_files
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
