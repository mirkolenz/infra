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

      # `nixos-hardware/apple` turns this on by default.
      services.mbpfan.enable = false;
    };
}
