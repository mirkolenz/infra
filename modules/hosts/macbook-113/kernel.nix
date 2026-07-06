{
  configurations.nixos.macbook-113.module =
    { pkgs, ... }:
    {
      boot.kernelParams = [
        "i915.modeset=0"
        # Deep C-states hard-freeze this MacBookPro11,3 (Haswell i7-4980HQ) on
        # idle, so cap them. C1E (max_cstate=2) is safe but saves almost no power;
        # C6 (index 4) power-gates the core for real idle savings while staying
        # below the C7+/package-C-state region the freeze reports implicate.
        #
        # intel_idle hsw_cstates table for this CPU; max_cstate = deepest allowed
        # index (index 0 is POLL; max_cstate=0 disables intel_idle entirely):
        #   idx  state  exit      powers down
        #    1   C1        2 us   clock gate only
        #    2   C1E      10 us   clock gate + Vmin   (previous cap; ~no savings)
        #    3   C3       33 us   core caches flushed, core voltage reduced
        #    4   C6      133 us   core power-gated    <- current: big idle-power win
        #    5   C7s     166 us   + package C7 begins (LLC / uncore power down)
        #    6   C8      300 us   package PC8   \
        #    7   C9      600 us   package PC9    >- deepest package; freeze-prone
        #    8   C10    2600 us   package PC10  /
        # https://www.thomas-krenn.com/en/wiki/Processor_P-states_and_C-states
        "intel_idle.max_cstate=4"
        "processor.max_cstate=4"
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
