{ config, lib, ... }:
{
  configurations.darwin.mirkos-macbook.module = {
    imports = [ config.flake.modules.darwin.default ];
    networking.computerName = "Mirkos MacBook";
    nixpkgs.hostPlatform = "aarch64-darwin";
    custom.features = {
      graphical.enable = lib.mkDefault true;
      extras.enable = lib.mkDefault true;
    };
  };
}
