{ lib, config, ... }:
{
  system.autoUpgrade = {
    flake = "github:mirkolenz/nixos";
    flags = lib.optional config.custom.impureRebuild "--impure";
    upgrade = false;
    dates = "04:00";
    allowReboot = true;
    runGarbageCollection = true;
    rebootWindow = {
      lower = "03:30";
      upper = "05:00";
    };
  };
}
