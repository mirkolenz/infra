{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.mosh;
in
{
  options.programs.mosh = {
    enable = lib.mkEnableOption "mosh";
    package = lib.mkPackageOption pkgs "mosh" { };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
