{ config, lib, ... }:
{
  configurations.darwin.mirkos-macbook.module = {
    imports = [ config.flake.modules.darwin.default ];
    networking.computerName = "Mirkos MacBook";
    nixpkgs.hostPlatform = "aarch64-darwin";
    custom.features = {
      withDisplay = lib.mkDefault true;
      withOptionals = lib.mkDefault true;
    };
  };
}
