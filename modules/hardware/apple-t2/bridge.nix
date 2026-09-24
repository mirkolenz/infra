# The internal CDC-NCM link Touch ID, the journal and AVE reach the T2 over.
# The virtual USB host controller reset-resumes it after a stateful sleep.
# The profile and the sleep commands below follow upstream's, which cannot be
# installed as files because they name Fedora paths.
# Derived from KaiT2en, (C) 2026 André Eikmeyer, GPL-3.0-or-later (LICENSING.md).
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/t2-services/shared/integration
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

      # The address of the T2's bridge interface, the same on every T2 Mac.
      mac = "ac:de:48:00:11:22";

      # The shared helper runs every executable in one directory.
      hooks = pkgs.symlinkJoin {
        name = "apple-t2-sleep-hooks";
        paths = cfg.sleepHooks;
      };

      ncm = lib.getExe pkgs.kait2en.ncm;

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

        sleepHooks = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          internal = true;
          description = ''
            Packages carrying an executable under `libexec/kait2en/sleep.d`,
            run with `pre` before sleep and `post` after resume.
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

          networking.networkmanager = {
            # The link can re-enumerate, and NetworkManager would accumulate a
            # fresh generic profile each time.
            settings.main.no-auto-default = mac;

            ensureProfiles.profiles.t2-bridge = {
              connection = {
                id = "Apple T2 Bridge";
                type = "ethernet";
                autoconnect = true;
                # The T2 is either there or it is not.
                autoconnect-retries = 0;
              };
              ethernet.mac-address = lib.toUpper mac;
              # There is nothing routable behind it, only the T2 itself.
              ipv4.method = "disabled";
              ipv6.method = "link-local";
            };
          };

          systemd.services =
            lib.genAttrs cfg.services (_: {
              # Started by the link rather than `network-online.target`, which
              # would hold every boot behind `NetworkManager-wait-online` for up
              # to 60s, waiting on every other profile too. The AVE sleep hook
              # needs the daemon to remain running through suspend.
              wantedBy = [ bridgeDevice ];
              after = [
                bridgeDevice
                "NetworkManager.service"
              ];
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
                Restart = "on-failure";
                RestartSec = 1;
                RestartSteps = 5;
                RestartMaxDelaySec = 30;
              };
            })
            // {
              # The AVE hook can take 125s, past the 90s systemd would allow.
              sleep-actions = {
                after = [ "NetworkManager.service" ];
                serviceConfig = {
                  TimeoutStartSec = 180;
                  TimeoutStopSec = 300;
                };
              };
            };

          # Down last and back first, so the other devices transition after
          # the AVE session closes and before it reopens.
          powerManagement = {
            powerDownCommands = lib.mkAfter ''
              T2_HOOK_DIR=${hooks}/libexec/kait2en/sleep.d ${ncm} pre
            '';
            resumeCommands = lib.mkBefore ''
              T2_HOOK_DIR=${hooks}/libexec/kait2en/sleep.d ${ncm} post
            '';
          };
        })
      ];
    };
}
