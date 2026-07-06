{
  inputs,
  config,
  ...
}:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos.macbook-113.module = {
    imports = [
      nixos.default
      "${inputs.nixos-hardware}/apple"
      "${inputs.nixos-hardware}/common/cpu/intel/haswell/cpu-only.nix"
      "${inputs.nixos-hardware}/common/pc/laptop"
      "${inputs.nixos-hardware}/common/pc/ssd"
    ];

    custom.features = {
      graphical.desktopManager = "cosmic";
      extras.enable = true;
    };

    boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
    boot.loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      efi.efiSysMountPoint = "/boot";
    };

    swapDevices = [
      {
        device = "/swapfile";
        size = 4 * 1024;
      }
    ];
  };
}
