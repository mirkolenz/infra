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
      # Without i915, the PCH audio controller would defer its probe forever, waiting for the audio component.
      boot.kernelParams = [
        "i915.modeset=0"
        "snd_hda_core.gpu_bind=0"
      ];

      # nouveau garbles the DMA-BUF buffers that WebKitGTK shares, e.g. in GNOME Help.
      environment.sessionVariables.WEBKIT_DISABLE_DMABUF_RENDERER = "1";
    };
  };
}
