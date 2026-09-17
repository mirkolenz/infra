{
  inputs,
  config,
  ...
}:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos.macbook-161 = {
    system = "x86_64-linux";
    module =
      {
        pkgs,
        ...
      }:
      {
        imports = [
          nixos.default
          nixos.apple-t2
          "${inputs.nixos-hardware}/apple"
          # Not `cpu-only`: the GPU half brings the VA-API and compute drivers
          # for the Intel graphics, which nothing else configures, and it sets
          # the same `i915.enable_guc=2` KaiT2en asks for.
          "${inputs.nixos-hardware}/common/cpu/intel/coffee-lake"
          "${inputs.nixos-hardware}/common/pc/laptop"
          "${inputs.nixos-hardware}/common/pc/ssd"
        ];

        custom.apple-t2 = {
          firmware.enable = true;
          # Parks the discrete GPU, which on this model otherwise trips CATERR.
          hybridGraphics.enable = true;
          touchid.enable = true;
          ave.enable = true;
        };

        # The Intel GPU module loads i915 from the initrd, which would put a
        # display driver in front of `t2gmux` before it has assigned the panel.
        # Nothing in stage 1 needs a console that early.
        hardware.intelgpu.loadInInitrd = false;
        custom.features = {
          graphical.desktopManager = "gnome";
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

        environment.systemPackages = with pkgs; [
          brightnessctl
        ];

        # https://github.com/AsahiLinux/tiny-dfr/blob/master/share/tiny-dfr/config.toml
        hardware.apple.touchBar = {
          enable = true;
          settings = {
            MediaLayerDefault = true;
          };
        };
      };
  };
}
