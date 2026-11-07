{
  flake.modules.homeManager.default =
    { pkgs, config, ... }:
    {
      home.packages = with pkgs; [
        gibo
        git-filter-repo
      ];
      programs.git = {
        enable = true;
        lfs.enable = true;
        ignores = [
          # nix
          ".devenv"
          ".direnv"
          ".env"
          ".envrc"
          "result"
          "result-*"
          # editors
          ".idea/*"
          ".vscode/*"
          ".zed/*"
          # https://github.com/github/gitignore/blob/main/Global/macOS.gitignore
          ".DS_Store"
          ".AppleDouble"
          ".LSOverride"
          "Icon[]"
          "._*"
          ".DocumentRevisions-V100"
          ".fseventsd"
          ".Spotlight-V100"
          ".TemporaryItems"
          ".Trashes"
          ".VolumeIcon.icns"
          ".com.apple.timemachine.donotpresent"
          ".AppleDB"
          ".AppleDesktop"
          "Network Trash Folder"
          "Temporary Items"
          ".apdisk"
          # linux
          "*~"
          ".fuse_hidden*"
          ".directory"
          ".Trash-*"
          ".nfs*"
          "nohup.out"
          # https://github.com/github/gitignore/blob/main/Global/Windows.gitignore
          "Thumbs.db"
          "Thumbs.db:encryptable"
          "ehthumbs.db"
          "ehthumbs_vista.db"
          "*.stackdump"
          "[Dd]esktop.ini"
          "$RECYCLE.BIN/"
          "*.cab"
          "*.msi"
          "*.msix"
          "*.msm"
          "*.msp"
          "*.lnk"
        ];
        # https://git-scm.com/docs/git-config
        settings = {
          user = {
            name = config.custom.user.name;
            email = config.custom.user.mail;
          };
          core = {
            autocrlf = "input";
            eol = "lf";
            # editor = "micro";
            # not supported on linux
            # breaks nix flake operations with path references
            # https://github.com/NixOS/nix/issues/11567
            fsmonitor = false;
            # no hooks at all, so agents cannot plant one, as long as the repository config stays read-only
            hooksPath = "/dev/null";
          };
          feature = {
            manyFiles = true;
          };
          column = {
            ui = "auto";
          };
          branch = {
            sort = "-committerdate";
          };
          tag = {
            sort = "version:refname";
          };
          help = {
            autocorrect = "prompt";
          };
          commit = {
            verbose = true;
          };
          rerere = {
            enabled = true;
            autoupdate = true;
          };
          fetch = {
            all = true;
            prune = true;
            pruneTags = true;
            writeCommitGraph = true;
          };
          pull = {
            rebase = true;
          };
          rebase = {
            autoStash = true;
            autoSquash = true;
            updateRefs = true;
          };
          init = {
            defaultBranch = "main";
          };
          push = {
            followTags = true;
            autoSetupRemote = true;
          };
          remote = {
            # overwrite version tags
            # breaks git clone with "multiple updates for ref" errors
            # origin.fetch = "+refs/tags/v*:refs/tags/v*";
          };
          difftool.prompt = false;
          diff = {
            algorithm = "histogram";
            colorMoved = "default";
            tool = "nvimdiff";
          };
          mergetool.prompt = false;
          merge = {
            tool = "nvimdiff";
            conflictstyle = "diff3";
            # not compatible with mergiraf
            # conflictstyle = "zdiff3";
          };
        };
      };
    };
}
