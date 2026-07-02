{ config, ... }:
let
  inherit (config.flake.modules) nixos;
  module = system: {
    imports = [
      nixos.default
      nixos.parallels
    ];
    nixpkgs.hostPlatform = system;
  };
in
{
  # Shared parallels base (disko and users live in their own files).
  flake.modules.nixos.parallels = {
    custom.features = {
      withDisplay = true;
      desktop = "cosmic";
      withOptionals = true;
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
    parallels.module = module "aarch64-linux";
    parallels-intel.module = module "x86_64-linux";
  };
}
