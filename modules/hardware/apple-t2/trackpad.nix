# Force Touch trackpad. `t2_precision_trackpad` took the internal trackpad off
# `hid_t2magicmouse`, and puts the two pressure settings macOS exposes behind
# module parameters instead of a control panel.
# Upstream's t2-force-click is a root daemon whose boot half only restores
# those two parameters, which a modprobe line states once and for all.
# Its other half binds an action to the force click, which the driver reports
# as `BTN_TASK` on an input device of its own, `T2 Force Click Events`, so
# anything that can bind a button can do it without going through the daemon.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/apps/t2-force-click
{
  flake.modules.nixos.apple-t2 =
    { config, lib, ... }:
    let
      cfg = config.custom.apple-t2.trackpad;

      # What the driver's `click_strength` takes, in its own order.
      strengths = [
        "light"
        "medium"
        "firm"
      ];

      # The driver has no off switch for the force click, so its threshold is
      # put where a finger does not reach. The driver clamps pressure at 32767
      # and computes the threshold in an s32, which overflows past 21845 at
      # `firm`, so this sits just below that and near the sensor maximum.
      unreachable = 20000;
    in
    {
      options.custom.apple-t2.trackpad = {
        clickStrength = lib.mkOption {
          type = lib.types.enum strengths;
          default = "medium";
          description = ''
            How hard the trackpad has to be pressed for a plain click. The
            same three steps as macOS's own Click setting, which scale the
            firmware thresholds by 0.8, 1.0 and 1.2.
          '';
        };

        forceClickThreshold = lib.mkOption {
          type = lib.types.nullOr lib.types.ints.positive;
          default = 175;
          description = ''
            How hard a force click has to be, as a percentage of
            {option}`custom.apple-t2.trackpad.clickStrength`. Below roughly
            125 an ordinary click starts to cross it as well, and `null`
            turns the force click off.
          '';
        };
      };

      # Stated even at the defaults, so the settings survive an upstream change
      # of them and are visible where the rest of the machine is configured.
      config.boot.extraModprobeConfig = ''
        options t2_precision_trackpad click_strength=${
          toString (lib.lists.findFirstIndex (name: name == cfg.clickStrength) 0 strengths)
        } force_click_threshold_percent=${
          toString (if cfg.forceClickThreshold == null then unreachable else cfg.forceClickThreshold)
        }
      '';
    };
}
