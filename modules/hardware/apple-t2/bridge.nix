# The internal CDC-NCM link Touch ID, the journal and AVE reach the T2 over,
# and the sleep unit running their hooks. See `pkgs/by-name/kait2en/ncm.nix`.
{
  flake.modules.nixos.apple-t2 =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.custom.apple-t2.bridge;
      inherit (pkgs.kait2en) ncm;

      # The address of the T2's bridge interface, the same on every T2 Mac.
      mac = "ac:de:48:00:11:22";

      # The shared helper runs every executable in one directory.
      hooks = pkgs.symlinkJoin {
        name = "apple-t2-sleep-hooks";
        paths = cfg.packages;
      };

      # The net device tagged below by its USB IDs.
      bridgeDevice = "dev-t2bridge.device";
    in
    {
      options.custom.apple-t2.bridge = {
        enable = lib.mkEnableOption ''
          the T2 bridge link. Without it the interface is held down, since
          nothing else has a use for it and `network-online.target` would
          otherwise wait for it to time out
        '';

        packages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          internal = true;
          description = ''
            Packages of the daemons on the link, whose units get installed, and
            whose executables under `libexec/t2-services/sleep.d` run with `pre`
            before sleep and `post` after resume.
          '';
        };

        services = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          internal = true;
          description = ''
            Units of daemons that reach the T2 over the link, which all start
            after its device and NetworkManager and retry until it is addressed.
          '';
        };
      };

      config = lib.mkMerge [
        (lib.mkIf (!cfg.enable) {
          # Otherwise the `*-wait-online` units block until they give up on it.
          systemd.network.networks."10-t2-ethernet" = {
            matchConfig.MACAddress = mac;
            linkConfig = {
              ActivationPolicy = "manual";
              RequiredForOnline = false;
            };
          };

          networking.networkmanager.unmanaged = [ "mac:${mac}" ];
        })

        (lib.mkIf cfg.enable {
          environment.systemPackages = [ pkgs.kait2en.journal ];

          services.udev.extraRules = ''
            SUBSYSTEM=="net", SUBSYSTEMS=="usb", ATTRS{idVendor}=="05ac", ATTRS{idProduct}=="8233", TAG+="systemd", ENV{SYSTEMD_ALIAS}="/dev/t2bridge"
          '';

          # Copied rather than linked, since NetworkManager only loads a profile
          # owned by root with mode 0600.
          environment.etc = {
            "NetworkManager/conf.d/10-t2-services.conf".source =
              "${ncm}/etc/NetworkManager/conf.d/10-t2-services.conf";
            "NetworkManager/system-connections/t2-ncm.nmconnection" = {
              source = "${ncm}/etc/NetworkManager/system-connections/t2-ncm.nmconnection";
              mode = "0600";
            };
          };

          systemd.packages = [ ncm ] ++ cfg.packages;

          systemd.services =
            lib.genAttrs cfg.services (_: {
              # Started by the link rather than `network-online.target`, which
              # would hold every boot behind `NetworkManager-wait-online` for up
              # to 60s, waiting on every other profile too. The AVE sleep hook
              # needs the daemon to remain running through suspend.
              wantedBy = [ bridgeDevice ];
              after = [ bridgeDevice ];
              # The device exists before NetworkManager has addressed it, so the
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
            })
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
