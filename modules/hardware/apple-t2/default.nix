{
  flake.modules.nixos.apple-t2 =
    { lib, ... }:
    {
      options.custom.apple-t2.model = lib.mkOption {
        type = lib.types.str;
        example = "MacBookPro16,1";
        description = ''
          The DMI product name, which upstream's installer selects the speaker
          DSP by.
        '';
      };

      config = {
        # `nixos-hardware/apple` turns this on for the PCIe webcam of pre-T2 Macs.
        # Here the camera hangs off t2bce instead, so the module is dead weight.
        hardware.facetimehd.enable = false;
      };
    };
}
