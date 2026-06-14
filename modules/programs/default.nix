{
  flake.modules.homeManager.default =
    { ... }:
    {
      programs = {
        # keep-sorted start
        btop.enable = true;
        carapace.enable = false;
        fastfetch.enable = true;
        home-manager.enable = true;
        htop.enable = true;
        jq.enable = true;
        jqp.enable = true;
        lazydocker.enable = true;
        less.enable = true;
        nix-index.enable = true;
        pandoc.enable = true;
        pay-respects.enable = true;
        ripgrep.enable = true;
        yazi.enable = true;
        # keep-sorted end
      };
    };
}
