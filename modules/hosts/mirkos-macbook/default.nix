{ config, lib, ... }:
{
  configurations.darwin.mirkos-macbook = {
    system = "aarch64-darwin";
    module = {
      imports = [ config.flake.modules.darwin.default ];
      networking.computerName = "Mirkos MacBook";
      services.onepassword-secrets.enable = true;
      custom.linuxBuilder = "orbstack";
      custom.features = {
        graphical.enable = lib.mkDefault true;
        extras.enable = lib.mkDefault true;
      };
    };
  };
}
