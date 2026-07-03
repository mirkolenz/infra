{
  flake.modules.homeManager.default =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    lib.mkIf config.custom.features.extras.enable {
      programs.mago.enable = true;

      home.packages = with pkgs; [
        php
        phpPackages.composer
        frankenphp
        phpactor # legacy language server
        phpstan # legacy type checker
      ];
    };
}
