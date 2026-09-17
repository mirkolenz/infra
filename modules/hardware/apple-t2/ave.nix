# The T2's audio/video engine. See `pkgs/by-name/kait2en/ave.nix`.
# The unit follows upstream's, whose `ExecStartPre` and `Group` are covered by
# `boot.kernelModules` and the systemd default here.
# Derived from KaiT2en, (C) 2026 André Eikmeyer, GPL-3.0-or-later (LICENSING.md).
# https://github.com/kaiT2en/KaiT2en-Fedora/blob/main/t2-services/t2-ave/integration/systemd/kait2en-t2-remote.service
{
  flake.modules.nixos.apple-t2 =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.custom.apple-t2.ave;
    in
    {
      options.custom.apple-t2.ave.enable = lib.mkEnableOption "the Apple T2 audio and video engine";

      config = lib.mkIf cfg.enable {
        custom.apple-t2.bridge = {
          enable = true;
          sleepHooks = [ pkgs.kait2en.ave ];
          services = [ "apple-t2-ave" ];
        };

        boot.kernelModules = [ "t2bce_ave" ];

        systemd.services.apple-t2-ave = {
          description = "Apple T2 AVE service";
          serviceConfig = {
            ExecStart = "${lib.getExe pkgs.kait2en.ave} daemon";
            RestartSec = 2;
            UMask = "0007";
          };
        };
      };
    };
}
