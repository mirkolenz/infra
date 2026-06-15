{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkPackageOption
    mkIf
    ;

  cfg = config.programs.devenv;
  devenv = if cfg.package != null then lib.getExe cfg.package else "devenv";
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  options.programs.devenv = {
    enable = mkEnableOption "devenv";

    package = mkPackageOption pkgs "devenv" { nullable = true; };

    enableBashIntegration = lib.hm.shell.mkBashIntegrationOption { inherit config; };

    enableFishIntegration = lib.hm.shell.mkFishIntegrationOption { inherit config; };

    enableNushellIntegration = lib.hm.shell.mkNushellIntegrationOption { inherit config; };

    enableZshIntegration = lib.hm.shell.mkZshIntegrationOption { inherit config; };
  };

  config = mkIf cfg.enable {
    home.packages = mkIf (cfg.package != null) [ cfg.package ];

    programs = {
      bash.initExtra = mkIf cfg.enableBashIntegration ''
        eval "$(${devenv} hook bash)"
      '';

      zsh.initContent = mkIf cfg.enableZshIntegration ''
        eval "$(${devenv} hook zsh)"
      '';

      fish.interactiveShellInit = mkIf cfg.enableFishIntegration ''
        ${devenv} hook fish | source
      '';

      # Nushell has no runtime eval, so the dynamic hook is rendered to a
      # store path at build time and sourced from there.
      nushell.extraConfig = mkIf (cfg.enableNushellIntegration && cfg.package != null) ''
        source ${
          pkgs.runCommand "devenv-hook.nu" { } ''
            ${lib.getExe cfg.package} hook nu >> "$out"
          ''
        }
      '';
    };
  };
}
