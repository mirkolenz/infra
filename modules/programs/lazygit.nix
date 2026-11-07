{
  flake.modules.homeManager.default =
    { lib, config, ... }:
    {
      programs.lazygit = {
        enable = true;
        # https://github.com/jesseduffield/lazygit/blob/master/docs/Config.md
        settings = {
          customCommands = [
            {
              key = "<alt+t>";
              context = "global";
              command = "git fetch --tags --force";
              description = "Force-fetch remote tags";
              loadingText = "Fetching tags";
            }
            {
              key = "<alt+p>";
              context = "global";
              command = "git pull --tags --force";
              description = "Force-pull with remote tags";
              loadingText = "Pulling";
            }
          ];
          gui = {
            expandedSidePanelWeight = 2;
            expandFocusedSidePanel = true;
            filterMode = "fuzzy";
            mainPanelSplitMode = "horizontal";
            nerdFontsVersion = "3";
            portraitModeAutoMaxWidth = 80;
            portraitModeAutoMinHeight = 20;
            showCommandLog = false;
            showFileTree = true;
            showNumstatInFilesView = true;
            showRandomTip = false;
            sidePanelWidth = 0.25;
            skipAmendWarning = true;
            skipDiscardChangeWarning = false;
            skipNoStagedFilesWarning = true;
            skipRewordInEditorWarning = false;
            skipStashWarning = false;
            splitDiff = "auto";
          };
          git = {
            autoFetch = false;
            autoRefresh = true;
            commit.autoWrapCommitMessage = false;
            parseEmoji = true;
            log = {
              order = "default";
              showGraph = "never";
            };
          };
          os.editPreset = "zed";
          update.method = "never";
          disableStartupPopups = true;
        };
      };
      programs.lazyworktree = {
        enable = lib.mkDefault config.custom.features.extras.enable;
        settings = {
          editor = "zed";
          icon_set = "nerd-font-v3";
          fuzzy_finder_input = true;
          theme = "monokai";
        };
      };
      home.shellAliases = {
        lg = lib.getExe config.programs.lazygit.package;
        lw = lib.mkIf config.programs.lazyworktree.enable (lib.getExe config.programs.lazyworktree.package);
      };
    };
}
