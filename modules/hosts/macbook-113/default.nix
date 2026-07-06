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

    boot.kernelParams = [
      "i915.modeset=0"
      # https://www.thomas-krenn.com/en/wiki/Processor_P-states_and_C-states
      "intel_idle.max_cstate=2"
      "processor.max_cstate=2"
    ];

    boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
    boot.loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      efi.efiSysMountPoint = "/boot";
    };

    boot.blacklistedKernelModules = [ "thunderbolt" ];

    swapDevices = [
      {
        device = "/swapfile";
        size = 4 * 1024;
      }
    ];
  };
}
