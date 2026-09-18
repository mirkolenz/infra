# Touch ID through a stock fingerprint stack, nothing patched. See
# `pkgs/by-name/kait2en/touchid.nix` for how the daemon reaches the sensor.
# `security.pam.services.*.fprintAuth` follows `services.fprintd.enable`, so
# login and sudo pick it up on their own.
# The unit and the fprintd drop-in follow upstream's, down to the reasoning
# restated below, since theirs name Fedora paths.
# Derived from KaiT2en, (C) 2026 André Eikmeyer, GPL-3.0-or-later (LICENSING.md).
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/t2-services/t2-touchid/integration
{
  flake.modules.nixos.apple-t2 =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.custom.apple-t2.touchid;

      # fprintd and the daemon meet here, so both units have to declare it
      # identically for the handshake to work.
      runtimeDirectory = "t2-touchid";
      socket = "/run/${runtimeDirectory}/fprint.sock";

      # Whoever can write to the socket authenticates.
      runtimeDirectoryConfig = {
        RuntimeDirectory = runtimeDirectory;
        RuntimeDirectoryMode = "0700";
        RuntimeDirectoryPreserve = true;
      };
    in
    {
      options.custom.apple-t2.touchid.enable = lib.mkEnableOption "the Apple T2 Touch ID sensor";

      config = lib.mkIf cfg.enable {
        custom.apple-t2.bridge = {
          enable = true;
          services = [ "apple-t2-touchid" ];
        };

        services.fprintd.enable = true;
        services.dbus.packages = [ pkgs.kait2en.touchid ];

        systemd.services.apple-t2-touchid = {
          description = "Apple T2 Touch ID bridge for fprintd";
          # Binding an identity runs `fprintd-enroll`, which answers itself.
          path = [ config.services.fprintd.package ];
          serviceConfig = {
            ExecStart = lib.concatStringsSep " " [
              (lib.getExe pkgs.kait2en.touchid)
              "--socket ${socket}"
              # Looks through the usual macOS ids for one with a finger enrolled.
              "--uid auto"
              # Plain verify, every other bit needs state only macOS has.
              "--flags 0"
              # Ownership only, the finger is still required at every login.
              "--bind-user ${config.custom.user.login}"
            ];
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
          }
          // runtimeDirectoryConfig;
        };

        # Otherwise the virtual device stays advertised and every sudo waits
        # for a finger nobody can report. Tied together, a stopped bridge is
        # simply no reader and PAM falls through to the password.
        systemd.services.fprintd = {
          requires = [ "apple-t2-touchid.service" ];
          after = [ "apple-t2-touchid.service" ];
          environment.FP_VIRTUAL_DEVICE_STORAGE = socket;
          serviceConfig = {
            ReadWritePaths = [ "/run/${runtimeDirectory}" ];
          }
          // runtimeDirectoryConfig;
        };
      };
    };
}
