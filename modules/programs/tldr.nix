{
  flake.modules.homeManager.default =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.extras.enable {
      home.packages = with pkgs; [
        tlrc
      ];
      services.tldr-update = {
        enable = true;
        package = pkgs.tlrc;
      };
    };
}
