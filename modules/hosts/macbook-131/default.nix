{
  inputs,
  config,
  ...
}:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos.macbook-131 = {
    system = "x86_64-linux";
    module = {
      imports = [
        nixos.default
        "${inputs.nixos-hardware}/apple/macbook-pro"
        # Not `cpu-only`: the GPU half brings the VA-API driver for the Iris 540.
        "${inputs.nixos-hardware}/common/cpu/intel/skylake"
        "${inputs.nixos-hardware}/common/pc/ssd"
      ];

      custom.features = {
        graphical.desktopManager = "gnome";
        extras.enable = true;
      };

      boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
      boot.loader.systemd-boot.enable = true;
    };
  };
}
