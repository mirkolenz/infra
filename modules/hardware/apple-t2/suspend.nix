# Broadcom Wi-Fi and Bluetooth across S3. See `pkgs/by-name/kait2en/suspend.nix`.
# Default order, between the dGPU and link pairs: it shares hardware with
# neither, so nothing orders it more tightly.
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
