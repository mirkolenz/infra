{
  flake.modules.homeManager.default =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      extras = config.custom.features.extras.enable;

      # Adds untracked files as new-file diffs to `git diff HEAD`. Those exit with 1,
      # which diffnav would take as a failed refresh.
      worktreeDiff = "git diff --no-ext-diff HEAD; git ls-files -z --others --exclude-standard | xargs -0 -I {} git diff --no-ext-diff --no-index -- /dev/null {}; true";
    in
    {
      home.packages = [ pkgs.diffedit3 ];
      programs.mergiraf = {
        enable = lib.mkDefault extras;
        enableGitIntegration = true;
        enableJujutsuIntegration = true;
      };
      programs.difftastic = {
        enable = lib.mkDefault extras;
        options = {
          background = "dark";
          color = "always";
          display = "inline"; # "side-by-side", "side-by-side-show-both", "inline"
        };
      };
      programs.diff-so-fancy = {
        enable = true;
      };
      programs.delta = {
        options = {
          dark = true;
          features = "zebra-dark";
          hyperlinks = true;
          line-numbers = false;
          keep-plus-minus-markers = true;
          navigate = true;
          syntax-theme = "Monokai Extended";
          # Red-green deficiency friendly palette: blue additions, orange deletions.
          # Overrides zebra-dark's red/green plus/minus styles (the main section
          # always wins over feature-provided options); zebra-dark's moved-line
          # map-styles stay since they already use colorblind-safe hues.
          # minus-style = ''syntax "#3a2400"'';
          # minus-emph-style = ''syntax "#5c3800"'';
          # plus-style = ''syntax "#002a4d"'';
          # plus-emph-style = ''syntax "#004680"'';
        };
      };
      # Both open in narrow terminals such as herdr on a phone, unlike lazygit.
      programs.diffnav = {
        enable = true;
        # https://github.com/dlvhdr/diffnav#configuration
        settings.ui = {
          fileTreeWidth = 24;
          hideHeader = true;
          icons = "nerd-fonts-full";
          # diffnav cannot switch the layout by width, so unified fits every screen
          sideBySide = false;
          # pairs with the delta syntax theme Monokai Extended
          theme = "monokai_pro";
        };
      };
      programs.hunk = {
        enable = true;
        # https://hunk.dev/docs/reference/config/
        settings = {
          menu_bar = false;
          theme = "monokai";
          wrap_lines = true;
          # `hunk diff` follows the working tree as agents change it
          vcs.watch = true;
        };
      };
      home.shellAliases = {
        dn = "${lib.getExe config.programs.diffnav.package} --watch-cmd ${lib.escapeShellArg worktreeDiff}";
        hk = "${lib.getExe config.programs.hunk.package} diff";
      };
    };
}
