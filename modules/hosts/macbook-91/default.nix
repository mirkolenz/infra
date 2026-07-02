{
  inputs,
  config,
  ...
}:
let
  inherit (config.flake.modules) nixos;
in
{
  # macbook-91 hosts a child user, so it builds on the `children` bucket.
  configurations.nixos.macbook-91.module = {
    imports = [
      nixos.children
      "${inputs.nixos-hardware}/apple"
      "${inputs.nixos-hardware}/common/cpu/intel/sandy-bridge/cpu-only.nix"
      "${inputs.nixos-hardware}/common/pc/laptop"
      "${inputs.nixos-hardware}/common/pc/ssd"
    ];
    nixpkgs.hostPlatform = "x86_64-linux";

    custom.features = {
      withDisplay = true;
      desktop = "cosmic";
    };

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

    boot.kernelParams = [
      "i915.modeset=0"
    ];
  };
}
