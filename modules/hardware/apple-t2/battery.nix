# The periodic full charge that lets the battery gauge recalibrate. See
# `pkgs/by-name/kait2en/smc-control.nix`.
{
  flake.modules.nixos.apple-t2 =
    { pkgs, ... }:
    {
      systemd.packages = [ pkgs.kait2en.smc-control ];
      systemd.services.t2-smc-gaugingd.wantedBy = [ "multi-user.target" ];
    };
}
