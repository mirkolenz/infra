# The SMC's power limit steps for the shared heatpipe. See
# `pkgs/by-name/kait2en/zone-power.nix`.
{
  flake.modules.nixos.apple-t2 =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      package = pkgs.kait2en.zone-power;
    in
    {
      options.custom.apple-t2.zone-power.enable = lib.mkEnableOption "the Apple T2 SMC power limits";

      config = lib.mkIf config.custom.apple-t2.zone-power.enable {
        environment.systemPackages = [ package ];
        systemd.packages = [ package ];
        systemd.services.t2-zonepowerd.wantedBy = [ "multi-user.target" ];
      };
    };
}
