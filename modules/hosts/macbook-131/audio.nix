{
  configurations.nixos.macbook-131.module =
    { config, ... }:
    {
      # The in-tree CS8409 driver does not set up the amplifiers,
      # leaving the speakers and the internal microphone silent.
      boot.extraModulePackages = [ config.boot.kernelPackages.snd-hda-macbookpro ];
    };
}
