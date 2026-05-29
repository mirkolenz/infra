{
  pkgs,
  lib,
  config,
  ...
}:
lib.mkIf config.custom.features.withOptionals {
  home.packages = with pkgs; [
    tlrc
  ];
  services.tldr-update = {
    enable = true;
    package = pkgs.tlrc;
  };
}
