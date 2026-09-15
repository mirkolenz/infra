{
  flake.modules.homeManager.default =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    lib.mkIf config.custom.features.extras.enable {
      home.packages = with pkgs; [
        shfmt
      ];
    };
}
