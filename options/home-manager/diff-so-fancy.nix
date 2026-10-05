# Extends home-manager's `programs.diff-so-fancy` with the jujutsu integration it does not provide.
# https://github.com/nix-community/home-manager/blob/master/modules/programs/diff-so-fancy.nix
{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.programs.diff-so-fancy;
in
{
  options.programs.diff-so-fancy.enableJujutsuIntegration = lib.mkEnableOption "jujutsu integration for diff-so-fancy";

  config = lib.mkIf (cfg.enable && cfg.enableJujutsuIntegration) {
    programs.jujutsu.settings.ui = {
      diff-formatter = ":git";
      pager = [
        "sh"
        "-c"
        "${lib.getExe pkgs.diff-so-fancy} | ${lib.getExe pkgs.less} ${lib.escapeShellArgs cfg.pagerOpts}"
      ];
    };
  };
}
