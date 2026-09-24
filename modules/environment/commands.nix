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
          if [ "$#" -lt 2 ]; then
            echo "Usage: $0 QUALITY FILE..." >&2
            exit 1
          fi
          quality="$1"
          shift

          exec mogrify -strip -interlace none -sampling-factor 4:2:0 -define jpeg:dct-method=float -quality "$quality" "$@"
        '';
        # https://masdilor.github.io/use-imagemagick-to-resize-and-compress-images/
        mogrify-resize = /* bash */ ''
          if [ "$#" -lt 3 ]; then
            echo "Usage: $0 QUALITY FINAL_SIZE FILE..." >&2
            exit 1
          fi
          quality="$1"
          shift
          final_size="$1"
          shift

          exec mogrify -filter Triangle -define filter:support=2 -thumbnail "$final_size" -unsharp 0.25x0.08+8.3+0.045 -dither None -posterize 136 -quality "$quality" -define jpeg:fancy-upsampling=off -define png:compression-filter=5 -define png:compression-level=9 -define png:compression-strategy=1 -define png:exclude-chunk=all -interlace none -colorspace sRGB "$@"
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
        # Only raster images are touched, text and vector graphics pass through untouched.
        # The distiller presets such as /ebook are avoided on purpose: they force a full
        # sRGB color conversion of every object, which is both lossy and around 20x slower.
        # https://ghostscript.readthedocs.io/en/latest/VectorDevices.html
        pdfcompress = /* bash */ ''
          if [ "$#" -lt 1 ]; then
            echo "Usage: $0 FILE [GHOSTSCRIPT_ARGS...]" >&2
            echo "Env: PDFCOMPRESS_DPI (default 300), PDFCOMPRESS_QUALITY (default 1.5, 0.1 best to 3 worst)" >&2
            exit 1
          fi

          file="$1"
          shift

          dpi="''${PDFCOMPRESS_DPI:-300}"
          quality="''${PDFCOMPRESS_QUALITY:-1.5}"

          # The JPEG quality factor has no command line switch and is only reachable
          # through the PostScript distiller parameters evaluated by -c.
          imagedict="<</QFactor $quality /Blend 1>>"

          tmpfile="$(mktemp)"
          trap 'rm -f "$tmpfile"' EXIT

          ${lib.getExe pkgs.ghostscript} \
            -dNOPAUSE -dQUIET -dBATCH -dSAFER \
            -sDEVICE=pdfwrite \
            -dCompatibilityLevel=1.7 \
            -dAutoRotatePages=/None \
            -dDownsampleColorImages=true \
            -dColorImageDownsampleType=/Bicubic \
            -dColorImageResolution="$dpi" \
            -dDownsampleGrayImages=true \
            -dGrayImageDownsampleType=/Bicubic \
            -dGrayImageResolution="$dpi" \
            -dDownsampleMonoImages=true \
            -dMonoImageResolution="$((dpi * 2))" \
            "$@" \
            -sOutputFile="$tmpfile" \
            -c "<</ColorACSImageDict $imagedict /GrayACSImageDict $imagedict>> setdistillerparams" \
            -f "$file"

          if [ "$(wc -c < "$tmpfile")" -lt "$(wc -c < "$file")" ]; then
            cat "$tmpfile" > "$file"
          else
            echo "Compression did not shrink $file, keeping the original" >&2
          fi
        '';
        # https://polylux.dev/book/external/pdfpc.html
        # https://touying-typ.github.io/docs/external/pdfpc
        typst2pdfpc = /* bash */ ''
          if [ "$#" -lt 1 ]; then
            echo "Usage: $0 FILENAME [TYPST_ARGS...]" >&2
            exit 1
          fi

          filename="''${1%.typ}"
          shift

          exec typst eval "$@" --root . \
            'query(<pdfpc-file>).first().value' \
            --in "./$filename.typ" \
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
        # Resolves the flake from the working directory, so run it in a checkout.
        nixrepl = /* bash */ ''
          exec nix repl --expr 'rec {
            self = builtins.getFlake ("git+file://" + toString ./.);
            pkgs = import <pkgs> {
              overlays = [ self.overlays.default ];
              config = self.nixpkgsConfig;
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
        # Discarding the known hosts file makes ssh announce the host key as
        # newly added on every run, so drop anything below an error.
        ssh-once = /* bash */ ''
          exec ssh -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" -o "LogLevel=ERROR" "$@"
        '';
        jlog = /* bash */ ''
          journalctl -a -o json "$@" | ${lib.getExe pkgs.lnav}
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
        wget-mirror = /* bash */ ''
          exec ${lib.getExe pkgs.wget} \
            --mirror \
            --convert-links \
            --adjust-extension \
            --page-requisites \
            --no-parent \
            --wait=1 \
            --random-wait \
            --user-agent="Mozilla/5.0" \
            "$@"
        '';
        gh-prs = /* bash */ ''
          if [ "$#" -lt 1 ]; then
            echo "Usage: $0 SELECT [GH_SEARCH_ARGS...]" >&2
            echo "Example: $0 '.title == \"PR_TITLE\"'" >&2
            exit 1
          fi
          filter="$1"
          shift

          prs="$(gh search prs --assignee @me --state open "$@" \
            --json title,url,number,repository)"

          matched="$(jq "[.[] | select($filter)]" <<<"$prs")"
          urls="$(jq -r '.[].url' <<<"$matched")"

          if [ -z "$urls" ]; then
            echo "No matching pull requests found."
            exit 0
          fi

          echo "Matching pull requests:"
          echo
          jq -r '
            ["REPOSITORY", "ID", "TITLE"],
            (.[] | [.repository.nameWithOwner, "#\(.number)", .title])
            | @tsv
          ' <<<"$matched" | column -t -s $'\t'
          echo

          read -r -n 1 -p "How should they be merged? (s)quash/(m)erge/(r)ebase, any other key to skip " method
          echo

          case "$method" in
            s) mergeArg="--squash" ;;
            m) mergeArg="--merge" ;;
            r) mergeArg="--rebase" ;;
            *) echo "Nothing merged."; exit 0 ;;
          esac

          xargs -I {} gh pr merge {} "$mergeArg" --delete-branch --auto <<<"$urls"
        '';
        ffmpeg2web = ''
          if [ "$#" -lt 1 ]; then
            echo "Usage: $0 INPUT_FILE [FFMPEG_ARGS...]" >&2
            exit 1
          fi

          input="$1"
          shift

          exec ffmpeg -i "$input" \
            -vf "scale='min(1920,iw)':-2:flags=lanczos" \
            -c:v libx264 \
            -preset veryslow \
            -profile:v high \
            -pix_fmt yuv420p \
            -c:a aac \
            -b:a 128k \
            -ac 2 \
            -movflags \
            +faststart \
            "$@"
        '';
        ffmpeg2poster = ''
          if [ "$#" -lt 1 ]; then
            echo "Usage: $0 INPUT_FILE [FFMPEG_ARGS...] OUTPUT_FILE" >&2
            echo "Pass -ss SECONDS to skip black intros longer than the 300 analyzed frames" >&2
            exit 1
          fi

          input="$1"
          shift

          exec ffmpeg -i "$input" \
            -vf "thumbnail=300,scale='min(1920,iw)':-2:flags=lanczos" \
            -frames:v 1 \
            -update 1 \
            -q:v 2 \
            "$@"
        '';
      };
    };
}
