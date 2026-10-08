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
        "${inputs.nixos-hardware}/common/pc/ssd"
      ];

      # nixos-hardware's Skylake GPU profile without its `i915.enable_guc=2`.
      # i915 keeps GuC and HuC off before Gen12, the parameter taints the kernel,
      # and HuC only adds rate control to low-power H.264 encoding in i965.
      # i965 with the hybrid codec is the only driver that decodes VP9 on Skylake.
      hardware.intelgpu = {
        vaapiDriver = "intel-vaapi-driver";
        enableHybridCodec = true;
      };

      custom.features = {
        graphical.desktopManager = "gnome";
        extras.enable = true;
      };

      boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
      boot.loader.systemd-boot.enable = true;
    };
  };
}
