# PipeWire audio stack with ALSA (incl. 32-bit) and realtime scheduling.
{
  flake.modules.nixos.base =
    {
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.withDisplay {
      services.pipewire = {
        enable = true;
        alsa = {
          enable = true;
          support32Bit = true;
        };
      };

      security.rtkit.enable = config.services.pipewire.enable;
    };
}
