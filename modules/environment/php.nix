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
      ];
      # https://blog.packagist.com/composer-2-11-release/
      home.sessionVariables.COMPOSER_POLICY_COOLDOWN_PERIOD =
        config.custom.minReleaseAge.packagist * 24 * 60 * 60; # seconds
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
