{
  flake.modules.homeManager.default =
    { config, lib, ... }:
    let
      extras = config.custom.features.extras.enable;
    in
    {
      programs = {
        # keep-sorted start
        btop.enable = true;
        fx.enable = true;
        home-manager.enable = true;
        htop.enable = true;
        jq.enable = true;
        lazydocker.enable = true;
        less.enable = true;
        # nix-index-database already sets lib.mkDefault true
        nix-index.enable = extras;
        pandoc.enable = lib.mkDefault extras;
        pay-respects.enable = true;
        yazi.enable = lib.mkDefault extras;
        # keep-sorted end
      };
    };
}
