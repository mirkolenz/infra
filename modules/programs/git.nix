{
  flake.modules.homeManager.default =
    { pkgs, config, ... }:
    {
      home.packages = with pkgs; [
        gibo
        git-absorb
        git-filter-repo
      ];
      custom.commands.git-redate = {
        runtimeInputs = [
          config.programs.git.package
          pkgs.coreutils
        ];
        text = /* bash */ ''
          # @describe Rewrite the author and committer dates of a commit and all commits after it
          #
          # HEAD gets the date, each earlier commit is one step older.
          # Example: git redate --commit c6922849 --date 2026-11-17T20:00+01:00
          # @option -c --commit    First commit to rewrite, defaulting to the first unpushed one
          # @option -d --date=now  Date of HEAD in any format of GNU date
          # @option -s --step=1    Seconds between consecutive commits

          if [ -z "$argc_commit" ]; then
            base="$(git merge-base '@{u}' HEAD)"
          elif ! base="$(git rev-parse --verify --quiet "$argc_commit^")"; then
            # Either a root commit or no commit at all.
            git rev-parse --verify "$argc_commit^{commit}" >/dev/null
          fi

          # Without a base, the range starts at the root commit.
          range="''${base:+$base..}HEAD"

          # The rebase drops merges, and each commit derives its date from its position in the range.
          count="$(git rev-list --count --no-merges "$range")"
          end="$(date --date="$argc_date" +%s)"
          export REDATE_RANGE="$range" REDATE_STEP="$argc_step"
          export REDATE_START=$((end - (count - 1) * argc_step))

          git rebase "''${base:---root}" --exec 'date="@$((REDATE_START + ($(git rev-list --count "$REDATE_RANGE") - 1) * REDATE_STEP))" && GIT_COMMITTER_DATE="$date" git commit --amend --no-edit --allow-empty --date="$date"'
        '';
      };
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
          # dependencies and caches of the toolchains, which also keeps the repository walk of the agents fast
          "node_modules/"
          ".venv/"
          "__pycache__/"
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
          # https://github.com/tummychow/git-absorb#configuration
          absorb = {
            maxStack = 50;
            oneFixupPerCommit = true;
            autoStageIfNothingStaged = true;
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
