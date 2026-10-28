# Installer ISO images from the nixos.installer bucket, keyed by system.
{ config, ... }:
let
  inherit (config.flake) modules;
in
{
  configurations.installer = {
    x86_64-linux = {
      default = modules.nixos.installer;
      # https://github.com/t2linux/nixos-t2-iso/blob/main/nix/t2-iso-minimal.nix
      apple-t2 = {
        imports = [
          modules.nixos.installer
          modules.nixos.apple-t2
        ];
      };
    };
    aarch64-linux.default = modules.nixos.installer;
  };
}
