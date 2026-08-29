{ config, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos.hetzner-cloud = {
    system = "x86_64-linux";
    module = {
      imports = [ nixos.default ];

      custom.features.unattended.enable = true;

      boot.loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
        efi.efiSysMountPoint = "/boot";
      };
    };
  };
}
