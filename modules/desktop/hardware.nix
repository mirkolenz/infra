# Graphics acceleration and MacBook peripherals (FaceTime HD camera, fan control).
{
  flake.modules.nixos.base =
    {
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.withDisplay {
      hardware = {
        graphics.enable = true;
        facetimehd.withCalibration = true;
      };

      services.mbpfan = {
        enable = false;
        aggressive = false;
      };
    };
}
