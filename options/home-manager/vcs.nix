{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.custom.vcs;
  is = pager: cfg.pager == pager;
  inherit (config.programs) delta difftastic;
  # https://github.com/jesseduffield/lazygit/blob/master/docs/Custom_DiffRenderers.md
  renderers = {
    delta.command = "${lib.getExe delta.finalPackage} --paging=never --width={{columnWidth}} --hyperlinks-file-link-format=\"lazygit-edit://{path}:{line}\"";
    diff-so-fancy.command = lib.getExe pkgs.diff-so-fancy;
    difftastic = {
      command = "${lib.getExe difftastic.package} ${
        lib.cli.toCommandLineShellGNU { } difftastic.options
      }";
      type = "extDiff";
    };
  };
  enabled = lib.filterAttrs (name: _: config.programs.${name}.enable) renderers;
in
{
  options.custom.vcs = {
    pager = lib.mkOption {
      type = lib.types.enum (lib.attrNames renderers);
      default = "delta";
      description = ''
        Diff pager used by git, jujutsu, and as the default renderer of lazygit,
        which also enables its program.
      '';
    };
  };

  config = {
    programs.delta = {
      enable = lib.mkIf (is "delta") true;
      enableGitIntegration = is "delta";
      enableJujutsuIntegration = is "delta";
    };

    programs.diff-so-fancy = {
      enable = lib.mkIf (is "diff-so-fancy") true;
      enableGitIntegration = is "diff-so-fancy";
      enableJujutsuIntegration = is "diff-so-fancy";
    };

    programs.difftastic = {
      enable = lib.mkIf (is "difftastic") true;
      git.enable = is "difftastic";
      jujutsu.enable = is "difftastic";
    };

    # the first entry is the default, cycle through the other enabled ones with |
    programs.lazygit.settings.git.diffRenderers = [
      enabled.${cfg.pager}
    ]
    ++ lib.attrValues (removeAttrs enabled [ cfg.pager ]);
  };
}
