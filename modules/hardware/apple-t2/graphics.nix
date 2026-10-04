# GPU selection for the Intel/AMD MacBook Pros. `t2gmux` has no `force_igd`
# like `apple_gmux` had, so the panel is assigned by Apple's `gpu-power-prefs`
# EFI variable, read by the firmware at boot. A dGPU that ramps up can trip CPU
# CATERR and the SMC cuts power, which looks like a spontaneous reboot seconds
# into a session.
# https://github.com/kaiT2en/KaiT2en-Fedora/blob/main/website/docs/post-install/configuring-gpus.md
{
  flake.modules.nixos.apple-t2 =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (config.custom.apple-t2.graphics) mode;

      # Apple's own GUID. The first four bytes are the EFI attributes, the
      # fifth selects the GPU, 1 being the integrated one.
      prefs = "/sys/firmware/efi/efivars/gpu-power-prefs-fa4ce28d-b62f-4c99-9cc3-6815686e30f9";
      bootGpu =
        if mode == "discrete" then
          ''\x07\x00\x00\x00\x00\x00\x00\x00''
        else
          ''\x07\x00\x00\x00\x01\x00\x00\x00'';

      # Upstream's helpers rewrite the variable on every call, and this is NVRAM.
      setBootGpu = pkgs.writeShellApplication {
        name = "apple-t2-boot-gpu";
        runtimeInputs = with pkgs; [
          coreutils
          diffutils
          # chattr, for the immutable flag the kernel puts on EFI variables
          e2fsprogs
        ];
        text = ''
          if printf '${bootGpu}' | cmp -s - ${prefs}; then
            exit 0
          fi

          [ ! -e ${prefs} ] || chattr -i ${prefs}
          trap 'chattr +i ${prefs}' EXIT
          printf '${bootGpu}' > ${prefs}
        '';
      };
    in
    {
      options.custom.apple-t2.graphics.mode = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "integrated"
            "discrete"
            "hybrid"
          ]
        );
        default = null;
        description = ''
          The GPU driving the panel from the next boot on.
          `integrated` powers the dGPU off, `discrete` drives the panel from it,
          and `hybrid` keeps the panel on the iGPU while the dGPU sleeps until
          PRIME or an external display wakes it, on a MacBookPro15,1, 16,1 or 16,4.
          Writes the machine's `gpu-power-prefs` EFI variable, so leave it unset
          anywhere that must not change the host it runs on.
        '';
      };

      config = lib.mkMerge [
        # Caps a powered dGPU against the CATERR above.
        {
          services.udev.extraRules = ''
            SUBSYSTEM=="drm", DRIVERS=="amdgpu", ATTR{device/power_dpm_force_performance_level}="low"
          '';
        }

        # Points mutter at the iGPU whenever it drives the panel.
        # https://gitlab.gnome.org/GNOME/mutter/-/blob/main/doc/multi-gpu.md
        (lib.mkIf (mode != "discrete") {
          services.udev.extraRules = ''
            SUBSYSTEM=="drm", ENV{DEVTYPE}=="drm_minor", ENV{DEVNAME}=="/dev/dri/card[0-9]", SUBSYSTEMS=="pci", ATTRS{vendor}=="0x8086", TAG+="mutter-device-preferred-primary"
          '';
        })

        (lib.mkIf (mode != null) {
          systemd.services.apple-t2-gpu = {
            description = "Select the GPU driving the panel";
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = lib.getExe setBootGpu;
            };
          };
        })

        # Parks the dGPU after boot, and powers it up across S3, which it does
        # not survive powered down.
        (lib.mkIf (mode == "integrated") {
          systemd.packages = [ pkgs.kait2en.dgpu ];
          systemd.services = {
            kait2en-dgpu-off.wantedBy = [ "multi-user.target" ];
            kait2en-dgpu-suspend.wantedBy = [ "sleep.target" ];
          };
        })

        # A runtime-suspended dGPU stays off across S3 here, so no sleep hooks.
        (lib.mkIf (mode == "hybrid") {
          boot.extraModulePackages = [ pkgs.kait2en.amdgpu ];
          boot.extraModprobeConfig = pkgs.kait2en.amdgpu.modprobeConfig;
          services.udev.extraRules = ''
            SUBSYSTEM=="pci", ATTR{vendor}=="0x1002", ATTR{class}=="0x03*", ATTR{power/control}="auto"
          '';
        })
      ];
    };
}
