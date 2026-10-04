# Touch ID through a stock fingerprint stack, nothing patched. See
# `pkgs/by-name/kait2en/touchid.nix`.
# `security.pam.services.*.fprintAuth` follows `services.fprintd.enable`, so
# login and sudo pick it up on their own.
{
  flake.modules.nixos.apple-t2 =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      package = pkgs.kait2en.touchid;
    in
    {
      options.custom.apple-t2.touchid.enable = lib.mkEnableOption "the Apple T2 Touch ID sensor";

      config = lib.mkIf config.custom.apple-t2.touchid.enable {
        # Its units include the drop-in tying fprintd to the bridge.
        custom.apple-t2.bridge = {
          enable = true;
          packages = [ package ];
          services = [ "kait2en-t2-touchid" ];
        };

        services.fprintd.enable = true;
        services.dbus.packages = [ package ];

        # Binding an identity runs `fprintd-enroll`, which answers itself.
        systemd.services.kait2en-t2-touchid.path = [ config.services.fprintd.package ];

        # Upstream's installer binds the fingers to the user running it.
        environment.etc."kait2en/t2-touchid.conf".source = pkgs.substitute {
          src = "${package}/etc/kait2en/t2-touchid.conf";
          substitutions = [
            "--replace-fail"
            "T2_TOUCHID_BIND_USER=none"
            "T2_TOUCHID_BIND_USER=${config.custom.user.login}"
          ];
        };
      };
    };
}
