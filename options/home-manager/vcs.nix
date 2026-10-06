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
in
{
  options.custom.vcs = {
    pager = lib.mkOption {
      type = lib.types.enum (lib.attrNames renderers);
      default = "delta";
      description = ''
        Diff pager used by git, jujutsu, and as the default renderer of lazygit.
      '';
    };
  };

  config = {
    programs.delta = {
      enableGitIntegration = is "delta";
      enableJujutsuIntegration = is "delta";
    };

    programs.diff-so-fancy = {
      enableGitIntegration = is "diff-so-fancy";
      enableJujutsuIntegration = is "diff-so-fancy";
    };

    programs.difftastic = {
      git.enable = is "difftastic";
      jujutsu.enable = is "difftastic";
    };

    # the first entry is the default, cycle through the others with |
    programs.lazygit.settings.git.diffRenderers = [
      renderers.${cfg.pager}
    ]
    ++ lib.attrValues (removeAttrs renderers [ cfg.pager ]);
  };
}
