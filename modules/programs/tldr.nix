{
  flake.modules.homeManager.default =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.extras.enable {
      # tlrc refreshes its cache on its own once it is older than two weeks
      home.packages = with pkgs; [
        tlrc
      ];
    };
}
