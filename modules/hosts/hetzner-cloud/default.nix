{ config, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos.hetzner-cloud.module = {
    imports = [ nixos.default ];
    nixpkgs.hostPlatform = "x86_64-linux";

    custom.features.unattended.enable = true;

    boot.loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      efi.efiSysMountPoint = "/boot";
    };
  };
}
