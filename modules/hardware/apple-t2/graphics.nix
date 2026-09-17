# Hybrid graphics. `t2gmux` has no `force_igd` like `apple_gmux` had, so the
# panel is assigned by Apple's `gpu-power-prefs` EFI variable and the dGPU is
# parked through vga_switcheroo. Keeping it off is not only a battery measure:
# a dGPU that ramps up trips CPU CATERR and the SMC cuts power, which looks
# like a spontaneous reboot seconds into a session.
# Reimplements upstream's t2-dgpu-control, which configures Fedora through
# `systemctl enable` and `/etc`.
# https://github.com/kaiT2en/KaiT2en-Fedora/blob/main/apps/t2-dgpu-control/contrib/t2-dgpu-control-helper
{
  flake.modules.nixos.apple-t2 =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.custom.apple-t2.hybridGraphics;

      switch = "/sys/kernel/debug/vgaswitcheroo/switch";
      # Apple's own GUID. The first four bytes are the EFI attributes, the
      # fifth selects the GPU, 1 being the integrated one.
      bootGpu = "/sys/firmware/efi/efivars/gpu-power-prefs-fa4ce28d-b62f-4c99-9cc3-6815686e30f9";
      integrated = ''\x07\x00\x00\x00\x01\x00\x00\x00'';

      # Set when the dGPU was powered up only to survive a suspend.
      parked = "/run/apple-t2-dgpu-parked";

      dgpu = pkgs.writeShellApplication {
        name = "apple-t2-dgpu";
        runtimeInputs = with pkgs; [
          coreutils
          # chattr, for the immutable flag the kernel puts on EFI variables
          e2fsprogs
          diffutils
          gawk
        ];
        text = ''
          # One line per client, the active one marked `+`, power state last.
          active() { awk -F: '$3 == "+" { print $2; exit }' ${switch}; }
          powered() { awk -F: '$2 == "DIS" { print $4; exit }' ${switch}; }

          case "''${1-}" in
            boot-gpu)
              [ -e ${bootGpu} ] || exit 0
              # Only ever written when it actually differs, since this is NVRAM.
              if printf '${integrated}' | cmp -s - ${bootGpu}; then
                exit 0
              fi
              chattr -i ${bootGpu}
              trap 'chattr +i ${bootGpu}' EXIT
              printf '${integrated}' > ${bootGpu}
              ;;
            park)
              # Refuse while the panel is on the dGPU, which would black it out.
              [ "$(active)" = IGD ] || exit 0
              echo OFF > ${switch}
              ;;
            pre-sleep)
              rm -f ${parked}
              [ "$(powered)" = Off ] || exit 0
              echo ON > ${switch}
              touch ${parked}
              ;;
            post-sleep)
              [ -e ${parked} ] || exit 0
              rm -f ${parked}
              [ "$(active)" = IGD ] || exit 0
              echo OFF > ${switch}
              ;;
          esac
        '';
      };
    in
    {
      options.custom.apple-t2.hybridGraphics.enable = lib.mkEnableOption ''
        parking the discrete GPU and pinning the panel to the integrated one.
        Writes the machine's `gpu-power-prefs` EFI variable, so leave it off
        anywhere that must not change the host it runs on
      '';

      config = lib.mkIf cfg.enable {
        systemd.services.apple-t2-dgpu = {
          description = "Pin the panel to the integrated GPU and park the discrete one";
          wantedBy = [ "multi-user.target" ];
          after = [ "systemd-modules-load.service" ];
          unitConfig.ConditionPathExists = switch;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = [
              "${lib.getExe dgpu} boot-gpu"
              "${lib.getExe dgpu} park"
            ];
          };
        };

        # A powered-down dGPU does not come back from S3, so it goes up for the
        # transition and down again once the machine is awake.
        powerManagement = {
          powerDownCommands = "${lib.getExe dgpu} pre-sleep";
          resumeCommands = "${lib.getExe dgpu} post-sleep";
        };
      };
    };
}
