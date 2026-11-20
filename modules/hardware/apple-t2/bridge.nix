# The internal CDC-NCM link Touch ID, the journal and AVE reach the T2 over,
# and the sleep unit running their hooks. See `pkgs/by-name/kait2en/ncm.nix`
# and `ave.nix`. Without a daemon the link stays down.
{
  flake.modules.nixos.apple-t2 =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.custom.apple-t2;
      inherit (pkgs.kait2en) ncm;

      # The daemons that reach the T2 over the link, by unit. Their packages
      # install the units, and the executables under `libexec/t2-services/sleep.d`
      # that run with `pre` before sleep and `post` after resume.
      daemons =
        lib.optionalAttrs cfg.ave.enable { kait2en-t2-remote = pkgs.kait2en.ave; }
        // lib.optionalAttrs cfg.touchid.enable { kait2en-t2-touchid = pkgs.kait2en.touchid; };

      # The address of the T2's bridge interface, the same on every T2 Mac.
      mac = "ac:de:48:00:11:22";

      network = {
        matchConfig.MACAddress = mac;
        linkConfig.Unmanaged = true;
      };

      # The shared helper runs every executable in one directory.
      hooks = pkgs.symlinkJoin {
        name = "apple-t2-sleep-hooks";
        paths = lib.attrValues daemons;
      };

      # The net device tagged below by its USB IDs.
      bridgeDevice = "dev-t2bridge.device";
    in
    {
      options.custom.apple-t2.ave.enable = lib.mkEnableOption "the Apple T2 audio and video engine";

      config = lib.mkMerge [
        {
          # Upstream's `10-t2-services.conf`. NetworkManager would take the link
          # down on `PrepareForSleep`, before the suspend hooks close their T2
          # sessions, and the `*-wait-online` units would block on it.
          networking.networkmanager.unmanaged = [ "mac:${mac}" ];
          systemd.network.networks."10-t2-ethernet" = network;
          # The initrd loads `cdc_ncm` for USB Ethernet adapters, which also brings up the link.
          boot.initrd.systemd.network.networks."10-t2-ethernet" = network;
        }

        (lib.mkIf (daemons != { }) {
          environment.systemPackages = [ pkgs.kait2en.journal ];

          # Upstream's rule brings the link up with a kernel link-local address.
          services.udev.packages = [ ncm ];
          services.udev.extraRules = ''
            SUBSYSTEM=="net", SUBSYSTEMS=="usb", ATTRS{idVendor}=="05ac", ATTRS{idProduct}=="8233", TAG+="systemd", ENV{SYSTEMD_ALIAS}="/dev/t2bridge"
          '';

          systemd.packages = [ ncm ] ++ lib.attrValues daemons;

          systemd.services =
            lib.mapAttrs (_: _: {
              # Started by the link rather than `network-online.target`, which
              # would hold every boot behind `NetworkManager-wait-online` for up
              # to 60s, waiting on every other profile too. The AVE sleep hook
              # needs the daemon to remain running through suspend.
              wantedBy = [ bridgeDevice ];
              after = [ bridgeDevice ];
              # The device exists before the kernel has addressed it, so the
              # first attempts lose that race. Ten starts back off over ~3min,
              # then stop until the next resume requests the unit again. The
              # window only has to outlast those three minutes. Not `infinity`,
              # which counts successful starts and would strand it after ten.
              unitConfig = {
                StartLimitIntervalSec = 600;
                StartLimitBurst = 10;
              };
              serviceConfig = {
                RestartSec = 1;
                RestartSteps = 5;
                RestartMaxDelaySec = 30;
              };
            }) daemons
            // {
              t2-services-suspend = {
                wantedBy = [ "sleep.target" ];
                environment.T2_HOOK_DIR = "${hooks}/libexec/t2-services/sleep.d";
              };
            };
        })
      ];
    };
}
