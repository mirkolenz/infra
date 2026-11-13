{
  inputs,
  config,
  ...
}:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos.macbook-113 = {
    system = "x86_64-linux";
    module = {
      imports = [
        nixos.default
        nixos.low-end
        "${inputs.nixos-hardware}/common/cpu/intel/haswell/cpu-only.nix"
        "${inputs.nixos-hardware}/common/pc/laptop"
      ];

      custom.features = {
        graphical.desktopManager = "gnome";
        extras.enable = true;
      };

      # The ambient light sensor drives GNOME's automatic screen brightness.
      hardware.sensor.iio.enable = true;

      boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
      boot.loader.systemd-boot.enable = true;
    };
  };
}
