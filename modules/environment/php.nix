{
  flake.modules.homeManager.default =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    lib.mkIf config.custom.features.extras.enable {
      programs.mago.enable = !config.custom.features.lowMemory.enable;

      home.packages = with pkgs; [
        php
        phpPackages.composer
        frankenphp
      ];
      custom.bump.composer = {
        lockfile = "composer.lock";
        ranges = "php";
        commands = [
          [
            (lib.getExe pkgs.phpPackages.composer)
            "update"
          ]
        ];
      };
    };
}
