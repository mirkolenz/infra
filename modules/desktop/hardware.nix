# Graphics acceleration and MacBook peripherals (fan control).
{
  flake.modules.nixos.base =
    {
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.graphical.enable {
      hardware.graphics.enable = true;

      services.mbpfan = {
        enable = false;
        aggressive = false;
      };
    };
}
