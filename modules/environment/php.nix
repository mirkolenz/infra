{
  flake.modules.homeManager.default =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    lib.mkIf config.custom.features.withOptionals {
      home.packages = with pkgs; [
        frankenphp
        php
        phpactor
        phpPackages.composer
        phpPackages.php-cs-fixer
        phpPackages.php-parallel-lint
        phpstan
        pretty-php
      ];
    };
}
