# Installer ISO images from the nixos.installer bucket, keyed by system.
{
  inputs,
  config,
  ...
}:
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
    aarch64-linux = {
      default = modules.nixos.installer;
      raspi = {
        imports = [
          modules.nixos.installer
          "${inputs.nixos-hardware}/raspberry-pi/4"
        ];
        boot.tmp = {
          useTmpfs = true;
          tmpfsSize = "16G";
        };
      };
    };
  };
}
