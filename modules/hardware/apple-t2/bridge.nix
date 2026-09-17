# The internal CDC-NCM link Touch ID, the journal and AVE reach the T2 over.
# It does not survive suspend, which `pkgs/by-name/kait2en/ncm.nix` works around.
# The profile and the suspend unit below follow upstream's, which cannot be
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
            Units of daemons that reach the T2 over the link, which all take the
            same ordering: they cannot talk to it before NetworkManager has
            brought the connection up.
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

          networking.networkmanager = {
            # The link re-enumerates on every resume, and NetworkManager would
            # accumulate a fresh generic profile each time.
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
              wantedBy = [ "multi-user.target" ];
              wants = [ "network-online.target" ];
              after = [
                "NetworkManager.service"
                "network-online.target"
              ];
              serviceConfig.Restart = "on-failure";
            })
            // {
              t2-services-suspend = {
                description = "Apple T2 bridge link suspend and resume";
                before = [ "sleep.target" ];
                after = [ "NetworkManager.service" ];
                wantedBy = [ "sleep.target" ];
                unitConfig.StopWhenUnneeded = true;
                environment.T2_HOOK_DIR = "${hooks}/libexec/kait2en/sleep.d";
                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  # Binding the link back is the slow half, and this is what
                  # upstream allows for it.
                  TimeoutStartSec = 180;
                  TimeoutStopSec = 300;
                  ExecStart = "${ncm} pre";
                  ExecStop = "${ncm} post";
                };
              };
            };
        })
      ];
    };
}
