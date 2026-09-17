# Broadcom Wi-Fi and Bluetooth across S3. See `pkgs/by-name/kait2en/suspend.nix`.
{
  flake.modules.nixos.apple-t2 =
    { lib, pkgs, ... }:
    let
      helper = lib.getExe pkgs.kait2en.suspend;
    in
    {
      powerManagement = {
        powerDownCommands = "${helper} pre";
        resumeCommands = "${helper} post";
      };
    };
}
