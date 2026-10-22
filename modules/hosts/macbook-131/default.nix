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
    module =
      { pkgs, ... }:
      {
        imports = [
          nixos.default
          nixos.low-memory
          nixos.apple-thunderbolt
          "${inputs.nixos-hardware}/apple/macbook-pro"
        ];

        # nixos-hardware's Skylake GPU profile without its `i915.enable_guc=2`.
        # i915 keeps GuC and HuC off before Gen12, the parameter taints the kernel,
        # and HuC only adds rate control to low-power H.264 encoding in i965.
        # i965 with the hybrid codec is the only driver that decodes VP9 on Skylake.
        hardware.intelgpu = {
          vaapiDriver = "intel-vaapi-driver";
          enableHybridCodec = true;
        };

        # OpenCL and Level Zero on the GPU, the last runtime series to support Gen9.
        hardware.graphics.extraPackages = [ pkgs.intel-compute-runtime-legacy1 ];

        custom.features = {
          graphical.desktopManager = "gnome";
          extras.enable = true;
        };

        # The firmware does not opt into the IOMMU, so the kernel enables it only on request.
        # Without the firmware's external port markings, the kernel does not treat Thunderbolt
        # devices as untrusted, so bolt's authorization remains the actual DMA gate.
        boot.kernelParams = [ "intel_iommu=on" ];

        boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
        boot.loader.systemd-boot.enable = true;
      };
  };
}
