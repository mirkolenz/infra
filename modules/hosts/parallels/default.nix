{ config, ... }:
let
  inherit (config.flake.modules) nixos;
  module = {
    imports = [
      nixos.default
      nixos.parallels
    ];
  };
in
{
  # Shared parallels base (disko and users live in their own files).
  flake.modules.nixos.parallels = {
    custom.features = {
      graphical.desktopManager = "cosmic";
      extras.enable = true;
    };

    security.sudo.wheelNeedsPassword = false;

    boot.loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      efi.efiSysMountPoint = "/boot";
    };

    hardware.parallels.enable = true;
  };

  configurations.nixos = {
    parallels = {
      inherit module;
      system = "aarch64-linux";
    };
    parallels-intel = {
      inherit module;
      system = "x86_64-linux";
    };
  };
}
