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
    nixpkgs.hostPlatform = "x86_64-linux";

    custom.features = {
      graphical.desktopManager = "cosmic";
      extras.enable = true;
    };

    boot.kernelParams = [
      "i915.modeset=0"
      # https://www.thomas-krenn.com/en/wiki/Processor_P-states_and_C-states
      "intel_idle.max_cstate=3" # allow intel_idle states C0-C3 (sleep)
      # "processor.max_cstate=3" # allow acpi_idle states C0-C3 (sleep)
    ];

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

    systemd.sleep.settings.Sleep = {
      SuspendState = "freeze";
    };
  };
}
