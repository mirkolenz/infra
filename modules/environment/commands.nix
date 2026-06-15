{
  flake.modules.homeManager.default =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      home.packages = lib.mapAttrsToList (name: text: pkgs.writeShellApplication { inherit name text; }) {
        # https://masdilor.github.io/use-imagemagick-to-resize-and-compress-images/
        mogrify-convert = /* bash */ ''
          if [ "$#" -ne 3 ]; then
            echo "Usage: $0 INPUT_FILE OUTPUT_DIR QUALITY" >&2
            exit 1
          fi
          exec mogrify -path "$2" -strip -interlace none -sampling-factor 4:2:0 -define jpeg:dct-method=float -quality "$3" "$1"
        '';
        # https://masdilor.github.io/use-imagemagick-to-resize-and-compress-images/
        mogrify-resize = /* bash */ ''
          if [ "$#" -ne 4 ]; then
            echo "Usage: $0 INPUT_FILE OUTPUT_DIR QUALITY FINAL_SIZE" >&2
            exit 1
          fi
          exec mogrify -path "$2" -filter Triangle -define filter:support=2 -thumbnail "$4" -unsharp 0.25x0.08+8.3+0.045 -dither None -posterize 136 -quality "$3" -define jpeg:fancy-upsampling=off -define png:compression-filter=5 -define png:compression-level=9 -define png:compression-strategy=1 -define png:exclude-chunk=all -interlace none -colorspace sRGB "$1"
        '';
        gc = /* bash */ ''
          systemProfiles="$(find "/nix/var/nix/profiles" -type l -lname '*link*')"
          userProfiles="$(find "${config.xdg.stateHome}/nix/profiles" -type l -lname '*link*')"

          if [ -z "$systemProfiles" ]; then
            systemProfilesAnswer="n"
          else
            echo "Do you want to clean the following system profiles? (y/n)"
            echo "$systemProfiles"
            read -r -n 1 systemProfilesAnswer
            echo
          fi

          if [ -z "$userProfiles" ]; then
            userProfilesAnswer="n"
          else
            echo "Do you want to clean the following user profiles? (y/n)"
            echo "$userProfiles"
            read -r -n 1 userProfilesAnswer
            echo
          fi

          if [ "$systemProfilesAnswer" = "y" ]; then
            for profile in $systemProfiles; do
              echo "Processing profile $profile..."
              sudo nix profile wipe-history --older-than 7d --profile "$profile"
            done
          fi

          if [ "$userProfilesAnswer" = "y" ]; then
            for profile in $userProfiles; do
              echo "Processing profile $profile..."
              nix profile wipe-history --older-than 7d --profile "$profile"
            done
          fi

          echo "Collecting garbage..."
          nix store gc
          echo "Optimising store..."
          nix store optimise
        '';
        # https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/tasks/auto-upgrade.nix#L268
        needs-reboot = /* bash */ ''
          booted="$(readlink /run/booted-system/{initrd,kernel,kernel-modules})"
          built="$(readlink /nix/var/nix/profiles/system/{initrd,kernel,kernel-modules})"

          if [ "$booted" != "$built" ]; then
            echo "Reboot needed"
            exit 1
          else
            echo "No reboot needed"
            exit 0
          fi
        '';
        flakeup = /* bash */ ''
          exec nix flake update --commit-lock-file "$@"
        '';
        uvup = /* bash */ ''
          ${lib.getExe config.programs.uv.package} sync --all-extras --upgrade
          ${lib.getExe config.programs.git.package} commit -m "chore(deps/uv): update" uv.lock
        '';
        npmup = /* bash */ ''
          ${lib.getExe pkgs.npm-check-updates} --interactive --format group --install never
          ${lib.getExe' pkgs.nodejs "npm"} update
          ${lib.getExe config.programs.git.package} commit -m "chore(deps/npm): update" package.json package-lock.json
        '';
        dev = /* bash */ ''
          exec nix develop "$@"
        '';
        encrypt = /* bash */ ''
          if [ "$#" -ne 3 ]; then
            echo "Usage: $0 SOURCE TARGET RECIPIENT" >&2
            exit 1
          fi

          exec ${lib.getExe pkgs.gnupg} --output "$2" --encrypt --recipient "$3" "$1"
        '';
        decrypt = /* bash */ ''
          if [ "$#" -ne 2 ]; then
            echo "Usage: $0 SOURCE TARGET" >&2
            exit 1
          fi

          exec ${lib.getExe pkgs.gnupg} --output "$2" --decrypt "$1"
        '';
        backup = /* bash */ ''
          if [ "$#" -ne 2 ]; then
            echo "Usage: $0 SOURCE_PATH TARGET_DIR" >&2
            exit 1
          fi
          mkdir -p "$2"
          TIMESTAMP=$(date +"%Y-%m-%d-%H-%M-%S")
          sudo tar -czf "$2/$TIMESTAMP.tgz" "$1"
        '';
        restore = /* bash */ ''
          if [ "$#" -ne 2 ]; then
            echo "Usage: $0 SOURCE_PATH TARGET_DIR" >&2
            exit 1
          fi
          mkdir -p "$2"
          sudo tar -xzf "$1" -C "$2"
        '';
        compress = /* bash */ ''
          if [ "$#" -lt 1 ]; then
            echo "Usage: $0 SOURCE_PATH [TAR_ARGS...]" >&2
            exit 1
          fi
          source_path="$1"
          shift

          exec tar -czf "$source_path.tgz" "$source_path" "$@"
        '';
        decompress = /* bash */ ''
          if [ "$#" -lt 1 ]; then
            echo "Usage: $0 SOURCE_PATH [TAR_ARGS...]" >&2
            exit 1
          fi
          source_path="$1"
          shift

          exec tar -xzf "$source_path" "$@"
        '';
        # https://github.com/typst/typst/discussions/404#discussioncomment-9456308
        # https://stackoverflow.com/a/61677298
        pdfcompress = /* bash */ ''
          if [ "$#" -lt 2 ]; then
            echo "Usage: $0 SOURCE_PATH TARGET_PATH [GHOSTSCRIPT_ARGS...]" >&2
            exit 1
          fi

          source_path="$1"
          shift
          target_path="$1"
          shift

          exec ${lib.getExe pkgs.ghostscript} \
            -dNOPAUSE -dQUIET -dBATCH -dSAFER \
            -sDEVICE=pdfwrite \
            -dPDFSETTINGS=/ebook \
            -dAutoRotatePages=/None \
            -dCompatibilityLevel=1.7 \
            -dCompressFonts=true \
            -dConvertCMYKImagesToRGB=true \
            -dDetectDuplicateImages \
            -dEmbedAllFonts=true \
            -dOverPrint=/simulate \
            -dSubsetFonts=true \
            -dColorImageDownsampleType=/Bicubic \
            -dColorImageResolution=150 \
            -dGrayImageDownsampleType=/Bicubic \
            -dGrayImageResolution=150 \
            -dMonoImageDownsampleType=/Bicubic \
            -dMonoImageResolution=150 \
            "$@" \
            -sOutputFile="$target_path" \
            -f "$source_path"
        '';
        # https://polylux.dev/book/external/pdfpc.html
        # https://touying-typ.github.io/docs/external/pdfpc
        touying2pdfpc = /* bash */ ''
          if [ "$#" -lt 2 ]; then
            echo "Usage: $0 FILENAME [TYPST_ARGS...]" >&2
            exit 1
          fi

          filename="$1"
          shift

          typst query \
            --root . \
            "./$filename.typ" \
            --field value \
            --one "<pdfpc-file>" \
            > "./$filename.pdfpc"
        '';
        nixos-profile = /* bash */ ''
          if [ "$#" -lt 1 ]; then
            echo "Usage: $0 COMMAND [NIX_PROFILE_ARGS...]" >&2
            exit 1
          fi
          command="$1"
          shift
          exec nix profile "$command" --profile /nix/var/nix/profiles/system "$@"
        '';
        skim = /* bash */ ''
          exec open -g -a Skim "$@"
        '';
        prefetch-attr = /* bash */ ''
          if [ "$#" -lt 1 ]; then
            echo "Usage: $0 NIX_FLAKE_ATTR [NIX_PREFETCH_ARGS...]" >&2
            exit 1
          fi
          value="$(nix eval --raw "$1")"
          shift
          hash="$(nix store prefetch-file --json "$@" "$value" | jq -r .hash)"
          echo "hash = \"$hash\";"
        '';
        prefetch-attrs = /* bash */ ''
          if [ "$#" -lt 1 ]; then
            echo "Usage: $0 NIX_FLAKE_ATTRS [NIX_PREFETCH_ARGS...]" >&2
            exit 1
          fi
          TMPFILE="$(mktemp)"
          attrs="$1"
          shift
          echo "hashes = {" >> "$TMPFILE"
          nix eval --json "$attrs" \
            | jq -r 'to_entries[] | "\(.key) \(.value)"' \
            | while read -r key value; do
              echo "Evaluating $key" >&2
              hash="$(nix store prefetch-file --json "$@" "$value" | jq -r .hash)"
              echo "  $key = \"$hash\";" >> "$TMPFILE"
            done
          echo "};" >> "$TMPFILE"
          cat "$TMPFILE"
          rm "$TMPFILE"
        '';
        nix-flake-input = /* bash */ ''
          if [ "$#" -lt 1 ]; then
            echo "Usage: $0 INPUT_NAME [NIX_FLAKE_PREFETCH_ARGS...]" >&2
            exit 1
          fi
          input="$1"
          shift
          nix flake prefetch --inputs-from . "$input" --json "$@" | jq -r .storePath
        '';
        nixbuild-shell = /* bash */ ''
          exec rlwrap ssh eu.nixbuild.net shell
        '';
        nixrepl = /* bash */ ''
          exec nix repl --expr 'rec {
            self = builtins.getFlake ("git+file://" + toString ./.);
            cfg = builtins.getFlake "cfg";
            pkgs = import <pkgs> {
              overlays = [ cfg.overlays.default ];
              config = cfg.nixpkgsConfig;
            };
            lib = pkgs.lib;
          }' "$@"
        '';
        noeol = /* bash */ ''
          exec tr -d '\n'
        '';
        json-tool = /* bash */ ''
          exec ${lib.getExe pkgs.python3} -m json.tool "$@"
        '';
        http-server = /* bash */ ''
          exec ${lib.getExe pkgs.python3} -m http.server "$@"
        '';
        ssh-once = /* bash */ ''
          exec ssh -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" "$@"
        '';
        fontconvert = /* bash */ ''
          if [ "$#" -lt 2 ]; then
            echo "Usage: $0 SOURCE TARGET [FONTFORGE_ARGS...]" >&2
            exit 1
          fi
          source="$1"
          shift
          target="$1"
          shift
          exec fontforge -c "Open(\"$source\"); Generate(\"$target\");" "$@"
        '';
        gh-prs = /* bash */ ''
          if [ "$#" -lt 1 ]; then
            echo "Usage: $0 SELECT [GH_SEARCH_ARGS...]" >&2
            echo "Example: $0 '.title == \"PR_TITLE\"'" >&2
            exit 1
          fi
          filter="$1"
          shift

          prs="$(gh search prs --assignee @me --state open --limit 100 "$@" \
            --json title,url,number,repository)"

          matched="$(jq "[.[] | select($filter)]" <<<"$prs")"
          urls="$(jq -r '.[].url' <<<"$matched")"

          if [ -z "$urls" ]; then
            echo "No matching pull requests found."
            exit 0
          fi

          echo "The following pull requests will be merged:"
          echo
          jq -r '
            ["REPOSITORY", "ID", "TITLE"],
            (.[] | [.repository.nameWithOwner, "#\(.number)", .title])
            | @tsv
          ' <<<"$matched" | column -t -s $'\t'
          echo

          read -r -n 1 -p "Merge these pull requests? (y/n) " answer
          echo
          if [ "$answer" != "y" ]; then
            echo "Aborted." >&2
            exit 1
          fi

          xargs -I {} gh pr merge {} --squash --delete-branch --auto <<<"$urls"
        '';
      };
    };
}
