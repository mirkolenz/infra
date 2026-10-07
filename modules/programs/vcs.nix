{
  flake.modules.homeManager.default =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      gh = lib.getExe config.programs.gh.package;
      jq = lib.getExe config.programs.jq.package;
    in
    {
      home.packages = with pkgs; [
        gibo
        git-ignore
        git-filter-repo
        lazyjj
        diffedit3
        glab
      ];
      programs.gh = {
        enable = true;
        settings = {
          git_protocol = "ssh";
        };
      };
      programs.gh-dash = {
        enable = true;
      };
      programs.mergiraf = {
        enable = true;
        enableGitIntegration = true;
        enableJujutsuIntegration = true;
      };
      programs.difftastic = {
        enable = true;
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
        enable = true;
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
            # not compatible with jujutsu
            # origin.fetch = "+refs/tags/v*:refs/tags/v*";
          };
          difftool = {
            guiDefault = "auto";
            prompt = false;
          };
          diff = {
            algorithm = "histogram";
            colorMoved = "default";
            renames = true;
            guitool = "vscode";
          };
          mergetool = {
            guiDefault = "auto";
            prompt = false;
          };
          merge = {
            guitool = "vscode";
            conflictstyle = "diff3";
            # not compatible with mergiraf
            # conflictstyle = "zdiff3";
          };
        };
      };
      programs.jujutsu = {
        enable = true;
        # https://docs.jj-vcs.dev/latest/config/
        settings = {
          # keep-sorted start block=yes
          aliases = {
            # keep-sorted start block=yes
            c = [
              "commit"
            ];
            ci = [
              "commit"
              "--interactive"
            ];
            clone = [
              "git"
              "clone"
            ];
            d = [
              "describe"
            ];
            e = [
              "edit"
            ];
            f = [
              "git"
              "fetch"
            ];
            fetch = [
              "git"
              "fetch"
            ];
            init = [
              "git"
              "init"
            ];
            n = [
              "new"
            ];
            nb = [
              "bookmark"
              "create"
              "--revision"
              "@-"
            ];
            p = [
              "git"
              "push"
            ];
            pull = [
              "git"
              "fetch"
            ];
            push = [
              "git"
              "push"
            ];
            r = [
              "rebase"
            ];
            remote = [
              "git"
              "remote"
            ];
            s = [
              "squash"
            ];
            si = [
              "squash"
              "--interactive"
            ];
            tug = [
              "bookmark"
              "move"
              "--from"
              "closest_bookmark(@)"
              "--to"
              "closest_nonempty(@)"
            ];
            # keep-sorted end
          };
          # https://github.com/jj-vcs/jj/discussions/3549
          experimental-advance-branches = {
            enabled-branches = [
              "glob:*"
            ];
            disabled-branches = [
              "main"
              "glob:push-*"
            ];
          };
          revset-aliases = {
            "closest_bookmark(to)" = "heads(::to & bookmarks())";
            "closest_nonempty(to)" = "heads(::to ~ empty())";
          };
          ui = {
            default-command = "log";
            diff-editor = ":builtin";
            merge-editor = "mergiraf";
            # editor = "micro";
          };
          user = {
            name = config.custom.user.name;
            email = config.custom.user.mail;
          };
          # keep-sorted end
        };
      };
      programs.jjui = {
        enable = true;
      };
      programs.gitui = {
        enable = true;
        package = pkgs.gitui-bin;
        keyConfig = "${pkgs.gitui.src}/vim_style_key_config.ron";
      };
      programs.lazygit = {
        enable = true;
        # https://github.com/jesseduffield/lazygit/blob/master/docs/Config.md
        settings = {
          customCommands = [
            {
              key = "T";
              context = "global";
              command = "git fetch --tags --force";
              description = "Force-fetch remote tags";
              loadingText = "Fetching tags";
            }
          ];
          gui = {
            expandedSidePanelWeight = 2;
            expandFocusedSidePanel = true;
            filterMode = "fuzzy";
            mainPanelSplitMode = "horizontal";
            nerdFontsVersion = "3";
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
        enable = true;
        settings = {
          editor = "zed";
          icon_set = "nerd-font-v3";
          fuzzy_finder_input = true;
          theme = "monokai";
          custom_commands.universal = {
            c = {
              command = "claude";
              description = "Claude Code";
              show_help = true;
              new_tab = true;
            };
            e = {
              command = "zed";
              description = "Editor";
              show_help = true;
            };
          };
        };
      };
      home.shellAliases = {
        lg = lib.getExe config.programs.lazygit.package;
        lw = lib.getExe config.programs.lazyworktree.package;
      };
      custom.commands.gh-prs.text = /* bash */ ''
        # @describe Merge the open pull requests that match the given qualifiers and jq condition
        #
        # Example: gh-prs --repo mirkolenz/infra --author app/renovate
        # @option -m --method[squash|merge|rebase]  Merge method, asked for if absent
        # @option -a --author                       Author of the pull requests, such as app/renovate
        # @option -A --assignee                     Assignee of the pull requests, defaulting to @me without other qualifiers
        # @option -r --repo*                        Repository of the pull requests in owner/name format
        # @option -o --owner*                       Owner of the repositories
        # @option -f --filter=true                  jq condition on the title, url, number and repository of a pull request
        # @arg gh-args~                             Further arguments of gh search prs

        if [ -z "$argc_author$argc_assignee''${argc_repo[*]}''${argc_owner[*]}" ]; then
          argc_assignee="@me"
        fi

        matched="$(${gh} search prs --state open \
          ''${argc_author:+"--author=$argc_author"} \
          ''${argc_assignee:+"--assignee=$argc_assignee"} \
          "''${argc_repo[@]/#/--repo=}" \
          "''${argc_owner[@]/#/--owner=}" \
          "''${argc_gh_args[@]}" \
          --json title,url,number,repository --jq "[.[] | select($argc_filter)]")"

        if [ "$matched" = "[]" ]; then
          echo "No matching pull requests found."
          exit 0
        fi

        echo "Matching pull requests:"
        echo
        ${jq} -r '
          ["REPOSITORY", "ID", "TITLE"],
          (.[] | [.repository.nameWithOwner, "#\(.number)", .title])
          | @tsv
        ' <<<"$matched" | column -t -s $'\t'
        echo

        if [ -z "$argc_method" ]; then
          read -r -n 1 -p "How should they be merged? (s)quash/(m)erge/(r)ebase, any other key to skip " key
          echo

          case "$key" in
            s) argc_method="squash" ;;
            m) argc_method="merge" ;;
            r) argc_method="rebase" ;;
            *) echo "Nothing merged."; exit 0 ;;
          esac
        fi

        ${jq} -r '.[].url' <<<"$matched" |
          xargs -P 8 -I {} ${gh} pr merge {} "--$argc_method" --delete-branch --auto
      '';
    };
}
