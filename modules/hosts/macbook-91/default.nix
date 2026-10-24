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
  configurations.nixos.macbook-91 = {
    system = "x86_64-linux";
    module = {
      imports = [
        nixos.children
        "${inputs.nixos-hardware}/common/cpu/intel/cpu-only.nix"
        "${inputs.nixos-hardware}/common/pc/laptop"
      ];

      boot.loader.systemd-boot.enable = true;

      # The panel hangs on the GeForce, so i915 would only add a phantom LVDS-1,
      # and the kernel calls apple_set_os only on newer dual GPU models.
      boot.kernelParams = [
        "i915.modeset=0"
      ];
    };
  };
}
